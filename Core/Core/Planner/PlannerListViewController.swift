//
// This file is part of Canvas.
// Copyright (C) 2020-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import UIKit

protocol PlannerListDelegate: class, UIScrollViewDelegate {
    func plannerListWillRefresh()
    func getPlannables(from: Date, to: Date) -> GetPlannables
}

public class PlannerListViewController: UIViewController {
    @IBOutlet weak var emptyStateHeader: UILabel!
    @IBOutlet weak var emptyStateSubHeader: UILabel!
    @IBOutlet weak var emptyStateView: UIView!
    @IBOutlet weak var errorView: ListErrorView!
    let refreshControl = CircleRefreshControl()
    @IBOutlet weak var spinnerView: CircleProgressView!
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: PlannerListDelegate?
    let env = AppEnvironment.shared
    var start: Date = Clock.now.startOfDay() // inclusive
    var end: Date = Clock.now.startOfDay().addDays(1) // exclusive

    var plannables: Store<GetPlannables>?

    static func create(start: Date, end: Date, delegate: PlannerListDelegate?) -> PlannerListViewController {
        let controller = loadFromStoryboard()
        controller.delegate = delegate
        controller.start = start
        controller.end = end
        return controller
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        emptyStateHeader.text = NSLocalizedString("No Assignments", bundle: .core, comment: "")
        emptyStateSubHeader.text = NSLocalizedString("It looks like assignments haven’t been created in this space yet.", bundle: .core, comment: "")
        errorView.messageLabel.text = NSLocalizedString("There was an error loading events. Pull to refresh to try again.", bundle: .core, comment: "")
        errorView.retryButton.addTarget(self, action: #selector(retryAfterError), for: .primaryActionTriggered)

        refreshControl.addTarget(self, action: #selector(plannerListWillRefresh), for: .primaryActionTriggered)
        refreshControl.color = nil
        spinnerView.color = nil
        tableView.refreshControl = refreshControl
        tableView.separatorColor = .named(.borderMedium)

        refresh()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selected = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selected, animated: true)
        }
    }

    @objc func retryAfterError() {
        refreshControl.beginRefreshing()
        delegate?.plannerListWillRefresh()
    }

    @objc func plannerListWillRefresh() {
        delegate?.plannerListWillRefresh()
    }

    func refresh(force: Bool = false) {
        errorView.isHidden = true
        plannables = delegate.flatMap { env.subscribe($0.getPlannables(from: start, to: end)) { [weak self] in
            self?.updatePlannables()
        } }
        plannables?.refresh(force: force)
    }

    private func updatePlannables() {
        guard plannables?.requested == true, plannables?.pending == false else { return }
        refreshControl.endRefreshing()
        spinnerView.isHidden = true
        emptyStateView.isHidden = plannables?.error != nil || plannables?.isEmpty != true
        errorView.isHidden = plannables?.error == nil
        tableView.reloadData()
    }
}

extension PlannerListViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plannables?.count ?? 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlannerListCell = tableView.dequeue(for: indexPath)
        let p = plannables?[indexPath]
        cell.update(p)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let url = plannables?[indexPath]?.htmlURL else { return }
        env.router.route(to: url, from: self, options: .detail(embedInNav: true))
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.scrollViewWillBeginDragging?(scrollView)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.scrollViewDidScroll?(scrollView)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        delegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }
}

class PlannerListCell: UITableViewCell {
    @IBOutlet weak var points: DynamicLabel!
    @IBOutlet weak var dueDate: DynamicLabel!
    @IBOutlet weak var title: DynamicLabel!
    @IBOutlet weak var courseCode: DynamicLabel!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var icon: UIImageView!

    func update(_ p: Plannable?) {
        guard let p = p else { return }
        courseCode.text = p.contextName
        title.text = p.title
        dueDate.text = DateFormatter.localizedString(from: p.date, dateStyle: .medium, timeStyle: .short)
        icon.image = p.icon()

        if let value = p.pointsPossible {
            points.text = GradeFormatter.numberFormatter.string(from: NSNumber(value: value))
        } else { points.text = nil }
    }
}
