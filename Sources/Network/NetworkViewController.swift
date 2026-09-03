//
//  CocoaDebug
//  liman
//
//  Created by liman 02/02/2023.
//  Copyright © 2023 liman. All rights reserved.
//

import UIKit

class NetworkViewController: UIViewController {
    
    var reachEnd: Bool = true
    var firstIn: Bool = true
    var reloadDataFinish: Bool = true
    
    var models: Array<_HttpModel>?
    var cacheModels: Array<_HttpModel>?
    var searchModels: Array<_HttpModel>?
    
    var naviItemTitleLabel: UILabel?
    private var didCombineGlassBar = false

    // nil = no method filter. ponytail: not persisted in CocoaDebugSettings — resets when the
    // debugger is reopened, which is what you want from a transient filter.
    private var methodFilter: String?

    // request -> its position in the unfiltered capture list, so the row number is stable
    private var stableIndex: [ObjectIdentifier: Int] = [:]

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var deleteItem: UIBarButtonItem!
    @IBOutlet weak var naviItem: UINavigationItem!
    
    //MARK: - tool
    //搜索逻辑
    func searchLogic(_ searchText: String = "") {
        guard let cacheModels = cacheModels else {return}

        //忽略大小写
        let keyword = searchText.lowercased()
        searchModels = cacheModels.filter { model in
            (keyword.isEmpty || model.url.absoluteString.lowercased().contains(keyword))
                && (methodFilter == nil || model.method.uppercased() == methodFilter)
        }
        models = searchModels
    }

    //The number drawn on each row is the request's position in the FULL capture list, not its
    //row in the filtered list — otherwise applying or clearing a filter renumbers every request
    //and the same call answers to a different number. Keyed by object identity because
    //`models` is always a subset of the very same _HttpModel instances held in `cacheModels`.
    private func rebuildStableIndex() {
        stableIndex = [:]
        for (position, model) in (cacheModels ?? []).enumerated() {
            stableIndex[ObjectIdentifier(model)] = position
        }
    }

    //filter funnel in the bookmark slot — filled while a method filter is on, so the icon
    //itself reports the state even if the navi title truncates on iOS 26's glass bar
    private func updateMethodFilterIcon() {
        let name = methodFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
        searchBar.setImage(UIImage(systemName: name), for: .bookmark, state: .normal)
    }

    //MARK: - private
    func reloadHttp(needScrollToEnd: Bool = false) {
        
        if reloadDataFinish == false {return}
        
        if searchBar.isHidden != false {
            searchBar.isHidden = false
        }
        
        self.models = (_HttpDatasource.shared().httpModels as NSArray as? [_HttpModel])
        self.cacheModels = self.models
        self.rebuildStableIndex()

        self.searchLogic(CocoaDebugSettings.shared.networkSearchWord ?? "")
        
        //        dispatch_main_async_safe { [weak self] in
        self.reloadDataFinish = false
        self.tableView.reloadData {
            self.reloadDataFinish = true
        }
        
        if needScrollToEnd == false {return}
        
        //table下滑到底部
        if let count = self.models?.count {
            if count > 0 {
                //                    guard let firstIn = self.firstIn else {return}
                self.tableView.tableViewScrollToBottom(animated: !firstIn)
                self.firstIn = false
            }
        }
        //        }
    }
    @IBAction func didTapHammer(_ sender: Any) {
        guard let url = URL(string: Config.string1) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            self.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                UIApplication.shared.open(url)
            }
        }
    }
    
    //MARK: - init
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(didTapView))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        naviItemTitleLabel = UILabel.init(frame: CGRect(x: 0, y: 0, width: 80, height: 40))
        naviItemTitleLabel?.textAlignment = .center
        naviItemTitleLabel?.textColor = Color.mainGreen
        naviItemTitleLabel?.font = .boldSystemFont(ofSize: 20)
        naviItem.titleView = naviItemTitleLabel

        naviItemTitleLabel?.text = "🚀[0]"
        deleteItem.tintColor = Color.mainGreen
        
        //notification
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "reloadHttp_CocoaDebug"), object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.reloadHttp(needScrollToEnd: self?.reachEnd ?? true)
        }
        
        
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        
        //抖动bug
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        
        searchBar.delegate = self
        searchBar.text = CocoaDebugSettings.shared.networkSearchWord
        searchBar.isHidden = true

        //keep in sync with NetworkDetailViewController's search bar: the debugger's table, nav
        //bar and cells are all black, and this field used to be painted white on its own
        searchBar.barStyle = .black
        searchBar.tintColor = Color.mainGreen

        // HTTP-method filter lives on the search bar's built-in bookmark button: no new bar
        // button item (that would break combineBarItemsForGlass's hardcoded item layout) and
        // no scope bar (the storyboard pins this bar to 44pt and the table's top to a matching 44).
        searchBar.showsBookmarkButton = true
        updateMethodFilterIcon()
        
        //keep the magnifier: it used to be stripped here, which left this bar the only search
        //field in the debugger without one. searchTextField is the iOS 13+ API for what was a
        //`value(forKey: "searchField") as! UITextField` force-cast.
        let textFieldInsideSearchBar = searchBar.searchTextField
        textFieldInsideSearchBar.leftViewMode = .always
        textFieldInsideSearchBar.returnKeyType = .default
        
        reloadHttp(needScrollToEnd: true)
        
        if models?.count ?? 0 > CocoaDebugSettings.shared.networkLastIndex && CocoaDebugSettings.shared.networkLastIndex > 0 {
            tableView.tableViewScrollToIndex(index: CocoaDebugSettings.shared.networkLastIndex, animated: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 26.0, *) { combineBarItemsForGlass() }
    }

    // iOS 26's glass nav bar gives each bar button item a wide slot + generous spacing,
    // which starves the centered 🚀[count] titleView and collapses the extra items into a
    // "•••" overflow menu. Pack the auxiliary buttons into two grouped customView slots
    // ([up,hammer] and [trash,down]) so the bar has few wide slots and the count keeps its
    // center space. Mirrors the host app's own ind_combined approach.
    @available(iOS 26.0, *)
    private func combineBarItemsForGlass() {
        guard !didCombineGlassBar else { return }
        let left = navigationItem.leftBarButtonItems ?? []
        let right = navigationItem.rightBarButtonItems ?? []
        // Expected after the nav controller prepends the close button:
        // left = [closeX, up, hammer], right = [trash, down]
        guard left.count >= 3, right.count >= 2 else { return }
        didCombineGlassBar = true

        let closeX = left[0]
        let leftGroup = combinedGroup(Array(left[1...]))
        // A single trailing group renders its stack left-to-right, but the original
        // right items [trash, down] rendered as "down, trash" (trash at the edge).
        // Reverse so the combined stack preserves the original visual order.
        let rightGroup = combinedGroup(Array(right.reversed()))
        navigationItem.leftBarButtonItems = [closeX, leftGroup]
        navigationItem.rightBarButtonItems = [rightGroup]
    }

    @available(iOS 26.0, *)
    private func combinedGroup(_ items: [UIBarButtonItem]) -> UIBarButtonItem {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 20
        for it in items {
            let button = UIButton(type: .system)
            button.tintColor = Color.mainGreen
            if let img = it.image {
                button.setImage(img, for: .normal)
            } else if it.action == #selector(tapTrashButton(_:)) {
                button.setImage(UIImage(systemName: "trash"), for: .normal)
            }
            if let target = it.target, let action = it.action {
                button.addTarget(target, action: action, for: .touchUpInside)
            }
            stack.addArrangedSubview(button)
        }
        let group = UIBarButtonItem(customView: stack)
        group.hidesSharedBackground = true
        return group
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchBar.resignFirstResponder()
    }
    
    deinit {
        //notification
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - target action
    @IBAction func didTapDown(_ sender: Any) {
        tableView.tableViewScrollToBottom(animated: true)
        searchBar.resignFirstResponder()
        reachEnd = true
        CocoaDebugSettings.shared.networkLastIndex = 0
    }
    
    @IBAction func didTapUp(_ sender: Any) {
        tableView.tableViewScrollToHeader(animated: true)
        searchBar.resignFirstResponder()
        reachEnd = false
        CocoaDebugSettings.shared.networkLastIndex = 0
    }
    
    
    @IBAction func tapTrashButton(_ sender: UIBarButtonItem) {
        _HttpDatasource.shared().reset()
        models = []
        cacheModels = []
        //        searchBar.text = nil
        searchBar.resignFirstResponder()
        //        CocoaDebugSettings.shared.networkSearchWord = nil
        CocoaDebugSettings.shared.networkLastIndex = 0
        
        //        dispatch_main_async_safe { [weak self] in
        self.tableView.reloadData()
        self.naviItemTitleLabel?.text = "🚀[0]"
        self.naviItemTitleLabel?.sizeToFit()
        //        }
        
        NotificationCenter.default.post(name: NSNotification.Name("deleteAllLogs_CocoaDebug"), object: nil, userInfo: nil)
    }
    
    @objc func didTapView() {
        searchBar.resignFirstResponder()
    }
}

//MARK: - UITableViewDataSource
extension NetworkViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let count = models?.count {
            //active method filter is shown here so it is never invisible
            naviItemTitleLabel?.text = "🚀[" + String(count) + "]" + (methodFilter.map { " " + $0 } ?? "")
            naviItemTitleLabel?.sizeToFit()
            return count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NetworkCell", for: indexPath)
            as! NetworkCell
        
        let model = models?[indexPath.row]
        cell.httpModel = model
        //falls back to the row only if the map is stale (nothing should hit this)
        cell.index = model.flatMap { stableIndex[ObjectIdentifier($0)] } ?? indexPath.row
        return cell
    }
}

//MARK: - UITableViewDelegate
extension NetworkViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        guard let serverURL = CocoaDebugSettings.shared.serverURL else {return 0}
        let model = models?[indexPath.row]
        var height: CGFloat = 0.0
        
        if let cString = model?.url.absoluteString.cString(using: String.Encoding.utf8) {
            if let content_ = NSString(cString: cString, encoding: String.Encoding.utf8.rawValue) {
                
                if model?.url.absoluteString.contains(serverURL) == true {
                    //计算NSString高度
                    if #available(iOS 8.2, *) {
                        height = content_.height(with: UIFont.systemFont(ofSize: 13, weight: .heavy), constraintToWidth: (UIScreen.main.bounds.size.width - 92))
                    } else {
                        // Fallback on earlier versions
                        height = content_.height(with: UIFont.boldSystemFont(ofSize: 13), constraintToWidth: (UIScreen.main.bounds.size.width - 92))
                    }
                } else {
                    //计算NSString高度
                    if #available(iOS 8.2, *) {
                        height = content_.height(with: UIFont.systemFont(ofSize: 13, weight: .regular), constraintToWidth: (UIScreen.main.bounds.size.width - 92))
                    } else {
                        // Fallback on earlier versions
                        height = content_.height(with: UIFont.systemFont(ofSize: 13), constraintToWidth: (UIScreen.main.bounds.size.width - 92))
                    }
                }
                
                return height + 57
            }
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)
        searchBar.resignFirstResponder()
        reachEnd = false
        
        guard let models = models else {return}
        
        let vc: NetworkDetailViewController = NetworkDetailViewController.instanceFromStoryBoard()
        vc.httpModels = models
        vc.httpModel = models[indexPath.row]
        self.navigationController?.pushViewController(vc, animated: true)
        
        vc.justCancelCallback = { [weak self] in
            self?.tableView.reloadData()
        }
        
        CocoaDebugSettings.shared.networkLastIndex = indexPath.row
    }
}

//MARK: - UIScrollViewDelegate
extension NetworkViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
        reachEnd = false
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (scrollView.contentOffset.y + 1) >= (scrollView.contentSize.height - scrollView.frame.size.height) {
            //bottom reached
            reachEnd = true
        }
    }
}

//MARK: - UISearchBarDelegate
extension NetworkViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar)
    {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)
    {
        CocoaDebugSettings.shared.networkSearchWord = searchText
        searchLogic(searchText)

        //        dispatch_main_async_safe { [weak self] in
        self.tableView.reloadData()
        //        }
    }

    //filter by HTTP method. "All" clears it; the active one is checked here and shown in the navi title.
    func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()

        //only offer methods actually present in the captured traffic, plus whatever is already
        //selected (the trash button can empty out the method you are filtering on)
        let methods = Set((cacheModels ?? []).map { $0.method.uppercased() })
            .union(methodFilter.map { [$0] } ?? [])
            .sorted()

        let alert = UIAlertController(title: "Filter by HTTP method", message: nil, preferredStyle: .actionSheet)

        for title in ["All"] + methods {
            let isActive = (title == "All") ? methodFilter == nil : methodFilter == title
            let action = UIAlertAction(title: (isActive ? "✓ " : "") + title, style: .default) { [weak self] _ in
                self?.methodFilter = (title == "All") ? nil : title
                self?.updateMethodFilterIcon()
                self?.searchLogic(searchBar.text ?? "")
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.popoverPresentationController?.permittedArrowDirections = .init(rawValue: 0)
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)

        present(alert, animated: true, completion: nil)
    }
}
