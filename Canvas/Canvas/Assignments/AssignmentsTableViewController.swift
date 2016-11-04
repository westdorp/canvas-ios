//
//  AssignmentsTableViewController.swift
//  iCanvas
//
//  Created by Derrick Hathaway on 4/8/16.
//  Copyright © 2016 Instructure. All rights reserved.
//

import Foundation
import AssignmentKit
import SoPretty
import EnrollmentKit
import TooLegit
import ReactiveCocoa
import SoLazy
import SoPersistent
import Result
import TechDebt

extension Course {
    func totalGrade(gradingPeriodItem: GradingPeriodItem?) -> String {
        let grades: [String?]
        let empty = "-"

        if let gradingPeriodItem = gradingPeriodItem {
            switch gradingPeriodItem {
            case .Some(let gradingPeriod):
                grades = [visibleGradingPeriodGrade(gradingPeriod.id), visibleGradingPeriodScore(gradingPeriod.id)]
            case .All:
                guard totalForAllGradingPeriodsEnabled else {
                    return empty
                }
                grades = [visibleGradingPeriodGrade(nil), visibleGradingPeriodScore(nil)]
            }
        } else {
            grades = [visibleGrade, visibleScore]
        }

        let totalGrade = grades
            .flatMap { $0 }
            .joinWithSeparator("  ")

        if totalGrade.isEmpty {
            return empty
        }

        return totalGrade
    }
}

extension Assignment {
    func colorfulViewModel(dataSource: ContextDataSource) -> ColorfulViewModel {
        let model = ColorfulViewModel(style: .Basic)
        model.title.value = name
        model.color <~ dataSource.producer(ContextID(id: courseID, context: .Course)).map { $0?.color ?? .prettyGray() }
        model.icon.value = icon
        return model
    }
}

class AssignmentsTableViewController: Assignment.TableViewController, UISearchResultsUpdating, UISearchBarDelegate {
    let session: Session
    let courseID: String
    let route: (UIViewController, NSURL)->()
    
    var header: GradingPeriod.Header!
    var searchController: UISearchController!
    
    var multipleGradingPeriodsEnabled: Bool {
        return (session.enrollmentsDataSource[ContextID(id: courseID, context: .Course)] as? Course)?.multipleGradingPeriodsEnabled ?? false
    }

    init(session: Session, courseID: String, route: (UIViewController, NSURL)->()) throws {
        self.session = session
        self.courseID = courseID
        self.route = route

        super.init()

        header = try GradingPeriod.Header(session: self.session, courseID: self.courseID, viewController: self, includeGradingPeriods: multipleGradingPeriodsEnabled)
        header.selectedGradingPeriod.producer
            .startWithNext { [weak self] item in
                guard let me = self else { return }
                
                do {
                    try me.updateCollections(courseID, gradingPeriodID: item?.gradingPeriodID)
                } catch let error as NSError {
                    error.report(alertUserFrom: self)
                }
            }

        title = NSLocalizedString("Assignments", comment: "Title for Assignments view controller")

        cbi_canBecomeMaster = true
    }

    required init?(coder aDecoder: NSCoder) {
        ❨╯°□°❩╯⌢"I'm not ready for storyboards!"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if multipleGradingPeriodsEnabled {
            header.tableView.frame = CGRect(x: 0, y: 0, width: CGRectGetWidth(view.bounds), height: 44)
            tableView.tableHeaderView = header.tableView
            configureSearchController(header.tableView)
        } else {
            configureSearchController(tableView)
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        header.tableView.indexPathsForSelectedRows?.forEach { header.tableView.deselectRowAtIndexPath($0, animated: true) }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let assignment = collection[indexPath]
        route(self, assignment.htmlURL)
    }

    private func configureSearchController(table: UITableView) {
        // Initialize and perform a minimum configuration to the search controller.
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = NSLocalizedString("Search here...", comment: "Placeholder text for search bar on assignments page")
        searchController.searchBar.delegate = self
        searchController.searchBar.sizeToFit()
        table.tableHeaderView = searchController.searchBar
        
        if let refresher = refresher {
            refresher.refreshingBegan.observeNext({ [weak self] in
                self?.searchController.searchBar.userInteractionEnabled = false
            })
            
            refresher.refreshingCompleted.observeNext({ [weak self] _ in
                self?.searchController.searchBar.userInteractionEnabled = true
            })
        }
    }
    
    private func updateCollections(courseID: String, gradingPeriodID: String?, name: String?) throws {
        let collection = try self.collection(session, courseID: courseID, gradingPeriodID: gradingPeriodID, name: name)
        
        let invalidGradingPeriods = try GradingPeriod.gradingPeriodIDs(session, courseID: courseID, excludingGradingPeriodID: gradingPeriodID)
        let assignments = try Assignment.refreshSignalProducer(session, courseID: courseID, gradingPeriodID: gradingPeriodID, invalidatingGradingPeriodIDs: invalidGradingPeriods, cacheKey: cacheKey)
        let grades = try Grade.refreshSignalProducer(session, courseID: courseID, gradingPeriodID: gradingPeriodID).map { _ in () }
        let sync: SignalProducer<SignalProducer<Void, NSError>, NSError> = SignalProducer(values: [assignments, grades])
        
        let key = cacheKey(courseID, gradingPeriodID: gradingPeriodID)
        let refresher = SignalProducerRefresher(refreshSignalProducer: sync, scope: session.refreshScope, cacheKey: key)
        
        prepare(collection, refresher: refresher) { [weak self] (assignment: Assignment) -> ColorfulViewModel in
            guard let me = self else { return ColorfulViewModel(style: .Basic) }
            return me.viewModelFactory(assignment)
        }
        
        // manually show the refresh control because of some bug somewhere
        if refresher.shouldRefresh  {
            tableView.contentOffset = CGPoint(x: 0, y: tableView.contentOffset.y - refresher.refreshControl.frame.size.height)
        }
        
        refresher.refresh(false)
    }
    
    private func updateCollections(courseID: String, gradingPeriodID: String?) throws {
        let collection = try self.collection(session, courseID: courseID, gradingPeriodID: gradingPeriodID)

        let invalidGradingPeriods = try GradingPeriod.gradingPeriodIDs(session, courseID: courseID, excludingGradingPeriodID: gradingPeriodID)
        let assignments = try Assignment.refreshSignalProducer(session, courseID: courseID, gradingPeriodID: gradingPeriodID, invalidatingGradingPeriodIDs: invalidGradingPeriods, cacheKey: cacheKey)
        let grades = try Grade.refreshSignalProducer(session, courseID: courseID, gradingPeriodID: gradingPeriodID).map { _ in () }
        let sync: SignalProducer<SignalProducer<Void, NSError>, NSError> = SignalProducer(values: [assignments, grades])

        let key = cacheKey(courseID, gradingPeriodID: gradingPeriodID)
        
        let refresher = SignalProducerRefresher(refreshSignalProducer: sync.flatten(.Merge), scope: session.refreshScope, cacheKey: key)
        
        prepare(collection, refresher: refresher) { [weak self] (assignment: Assignment) -> ColorfulViewModel in
            guard let me = self else { return ColorfulViewModel(style: .Basic) }
            return me.viewModelFactory(assignment)
        }
        
        // manually show the refresh control because of some bug somewhere
        if refresher.shouldRefresh  {
            tableView.contentOffset = CGPoint(x: 0, y: tableView.contentOffset.y - refresher.refreshControl.frame.size.height)
        }

        refresher.refresh(false)
    }

    func collection(session: Session, courseID: String, gradingPeriodID: String?) throws -> FetchedCollection<Assignment> {
        return try Assignment.collectionByDueStatus(session, courseID: courseID, gradingPeriodID: gradingPeriodID)
    }
    
    func collection(session: Session, courseID: String, gradingPeriodID: String?, name: String?) throws -> FetchedCollection<Assignment> {
        return try Assignment.collectionByAssignmentName(session, courseID: courseID, gradingPeriodID: gradingPeriodID, name: name)
    }

    func viewModelFactory(assignment: Assignment) -> ColorfulViewModel {
        let dataSource = session.enrollmentsDataSource
        return assignment.colorfulViewModel(dataSource)
    }

    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let searchString = searchController.searchBar.text ?? ""
        
        let fuzzySearchString = self.fuzzySearchStringFormatter(searchString)
        
        do {
            try updateCollections(courseID, gradingPeriodID: header.selectedGradingPeriod.value?.gradingPeriodID, name: fuzzySearchString)
        } catch let error as NSError {
            error.presentAlertFromViewController(self)
        }
    }
    
    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
        guard let r = refresher else { return true }
        
        return !r.isRefreshing
    }
    
    private func fuzzySearchStringFormatter(searchString: String) -> String {
       let searchWithWildcards = NSMutableString(string: "*")
        
        searchString.enumerateSubstringsInRange(searchString.startIndex..<searchString.endIndex, options: NSStringEnumerationOptions.ByComposedCharacterSequences, { (substring, substringRange, enclosingRange, stop) -> () in
            if let substring = substring {
                searchWithWildcards.appendString(substring)
                searchWithWildcards.appendString("*")
            }
        })
        
        return searchWithWildcards as String
    }
    
}

func cacheKey(courseID: String, gradingPeriodID: String?) -> String {
    return ["assignments", courseID, gradingPeriodID].flatMap { $0 }.joinWithSeparator("//")
}

class GradesTableViewController: AssignmentsTableViewController {
    let gradesCollection: FetchedCollection<Grade>

    override init(session: Session, courseID: String, route: (UIViewController, NSURL) -> ()) throws {
        self.gradesCollection = try Grade.collectionByCourseID(session, courseID: courseID)

        try super.init(session: session, courseID: courseID, route: route)

        guard let course = session.enrollmentsDataSource[ContextID(id: courseID, context: .Course)] as? Course else {
            ❨╯°□°❩╯⌢"We should have a course."
        }

        let gradingPeriod = header.selectedGradingPeriod.producer
        let grades = SignalProducer<Void, NoError> { [weak self] observer, _ in
            observer.sendNext(())
            self?.gradesCollection.collectionUpdated = { _ in
                observer.sendNext(())
            }
        }

        header.grade <~ combineLatest(gradingPeriod, grades)
            .observeOn(UIScheduler())
            .map { gradingPeriodItem, _ in
                return course.totalGrade(gradingPeriodItem)
            }

        title = NSLocalizedString("Grades", comment: "Title for Grades view controller")
        
        cbi_canBecomeMaster = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        header.tableView.frame = CGRect(x: 0, y: 0, width: CGRectGetWidth(view.bounds), height: header.includeGradingPeriods ? 132 : 88)
        tableView.tableHeaderView = header.tableView
        configureSearchController(header.tableView)
    }

    override func viewModelFactory(assignment: Assignment) -> ColorfulViewModel {
        let dataSource = session.enrollmentsDataSource
        return assignment.gradeColorfulViewModel(dataSource)
    }

    override func collection(session: Session, courseID: String, gradingPeriodID: String?) throws -> FetchedCollection<Assignment> {
        return try Assignment.collectionByAssignmentGroup(session, courseID: courseID, gradingPeriodID: gradingPeriodID)
    }
}
