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
import Core

protocol SelectSessionProtocol: AnyObject {
    func didSelectSession(_ session: LoginSession)
}

class SelectSessionViewController: UITableViewController {

    var baseURL: URL!
    var sessions: [LoginSession] =  []
    weak var delegate: SelectSessionProtocol?

    static func create(baseURL: URL, delegate: SelectSessionProtocol) -> SelectSessionViewController {
        let controller = SelectSessionViewController(style: .plain)
        controller.modalPresentationStyle = .custom
        controller.modalPresentationCapturesStatusBarAppearance = true
        controller.transitioningDelegate = BottomSheetTransitioningDelegate.shared
        controller.baseURL = baseURL
        controller.delegate = delegate
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .named(.backgroundLightest)
        view.frame.size.height = 304
        sessions = LoginSession.sessions.filter { $0.baseURL.host == baseURL?.host }

        let identifier = String(describing: LoginStartSessionCell.self)
        tableView.register(UINib(nibName: identifier, bundle: nil), forCellReuseIdentifier: identifier)
        tableView.rowHeight = 70

        let header = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        let headerLabel = UILabel()
        headerLabel.font = UIFont.scaledNamedFont(.semibold14)
        headerLabel.textColor = .named(.textDark)
        headerLabel.text = NSLocalizedString("Which account should be paired?", comment: "")
        headerLabel.sizeToFit()
        headerLabel.numberOfLines = 0
        header.addSubview(headerLabel)
        headerLabel.pin(inside: header, leading: 16, trailing: 16, top: 12, bottom: 16)
        tableView.tableHeaderView = header
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: LoginStartSessionCell = tableView.dequeue(for: indexPath)
        cell.update(entry: sessions[indexPath.row], delegate: nil)
        cell.forgetButton?.isHidden = true
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        AppEnvironment.shared.loginDelegate?.userDidLogin(session: sessions[indexPath.row].bumpLastUsedAt())
        delegate?.didSelectSession(sessions[indexPath.row])
        AppEnvironment.shared.router.dismiss(self)
    }
}
