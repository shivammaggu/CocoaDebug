//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import Foundation
import UIKit
import MessageUI

class NetworkDetailViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    
    @IBOutlet weak var closeItem: UIBarButtonItem!
    @IBOutlet weak var naviItem: UINavigationItem!
    @IBOutlet weak var cURLItem: UIBarButtonItem!
    
    var naviItemTitleLabel: UILabel?
    
    var httpModel: _HttpModel?
    var httpModels: [_HttpModel]?
    
    var detailModels: [NetworkDetailModel] = [NetworkDetailModel]()
    
    var requestDictionary: [String: Any]? = Dictionary()
    
    var headerCell: NetworkCell?
    
    var messageBody: String = ""
    
    // Store complete response content for copy/email (before chunking)
    private var completeResponseContent: String? = nil
    
    var justCancelCallback:(() -> Void)?
    
    // Chunk size for splitting long content into multiple cells
    private let chunkSize = 5000

    // Search filters the sections down to the ones containing the text, and every match inside
    // them is highlighted by the cell.
    // NOTE: a match straddling two response chunks is still missed, and therefore also
    // undercounted — the chunks are scanned independently. completeResponseContent holds the
    // unchunked string, but counting against THAT would report matches the per-chunk cells
    // cannot highlight, which is the disagreement applySearch()'s single scan exists to avoid.
    private var unfilteredModels: [NetworkDetailModel] = []
    private var searchQuery: String = ""

    // The search bar rides INSIDE the section header, not in tableHeaderView (which scrolls
    // away) and not in navigationItem.searchController (starved by iOS 26's glass bar on this
    // screen — 3 right bar items plus a custom titleView). This table is plain-style, so its
    // section header floats: that is already what keeps the URL/status block pinned while you
    // scroll, and the search bar now inherits it.
    private let searchBarHeight: CGFloat = 56
    private lazy var searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.delegate = self
        bar.placeholder = "Search in details"
        bar.applyCocoaDebugDarkStyle(tint: Color.mainGreen)
        return bar
    }()
    private lazy var headerContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .black
        return container
    }()

    // How many matches the query has across the filtered sections. Only the total is reported;
    // there is no match-to-match navigation, so positions are never needed.
    private var matchCount: Int = 0

    private let matchBarHeight: CGFloat = 32
    private var matchBarHeightConstraint: NSLayoutConstraint?

    private lazy var matchLabel: UILabel = {
        let label = UILabel()
        label.textColor = Color.mainGreen
        label.font = .systemFont(ofSize: 13, weight: .medium)
        return label
    }()

    static func instanceFromStoryBoard() -> NetworkDetailViewController {
        let storyboard = UIStoryboard(name: "Network", bundle: Bundle(for: CocoaDebug.self))
        return storyboard.instantiateViewController(withIdentifier: "NetworkDetailViewController") as! NetworkDetailViewController
    }
    
    
    //MARK: - tool
    
    // Split long content into chunks and create multiple detail models
    func createChunkedModels(for content: String?, title: String, url: String?, httpModel: _HttpModel?) -> [NetworkDetailModel] {
        guard let content = content, !content.isEmpty else {
            return [NetworkDetailModel.init(title: title, content: content, url: url, httpModel: httpModel)]
        }
        
        let nsContent = content as NSString
        let totalLength = nsContent.length
        
        // If content is small enough, return single model
        guard totalLength > chunkSize else {
            return [NetworkDetailModel.init(title: title, content: content, url: url, httpModel: httpModel)]
        }
        
        // Split into chunks
        var chunkModels: [NetworkDetailModel] = []
        var currentIndex = 0
        var chunkIndex = 1
        
        while currentIndex < totalLength {
            let endIndex = min(currentIndex + chunkSize, totalLength)
            let range = NSRange(location: currentIndex, length: endIndex - currentIndex)
            let chunkContent = nsContent.substring(with: range)
            
            // Create a model for this chunk
            // First chunk keeps original title, subsequent chunks have no title (no header)
            let chunkTitle = chunkIndex == 1 ? title : nil
            var chunkModel = NetworkDetailModel.init(title: chunkTitle, content: chunkContent, url: url, httpModel: httpModel)
            
            // Copy httpModel properties if needed
            chunkModel.httpModel = httpModel
            
            // Mark as response chunk for divider handling
            chunkModel.blankContent = chunkIndex == 1 ? nil : "response_chunk"
            
            chunkModels.append(chunkModel)
            
            currentIndex = endIndex
            chunkIndex += 1
        }
        
        return chunkModels
    }
    
    func setupModels()
    {
        guard let requestSerializer = httpModel?.requestSerializer else {return}
        var requestContent: String? = nil
        
        //otherwise it will crash when it is nil
        if httpModel?.requestData == nil {
            httpModel?.requestData = Data.init()
        }
        if httpModel?.responseData == nil {
            httpModel?.responseData = Data.init()
        }
        
        //detect the request parameter format (JSON/Form)
        if requestSerializer == RequestSerializer.JSON {
            //JSON
            requestContent = httpModel?.requestData.dataToPrettyPrintString()
        }
        else if requestSerializer == RequestSerializer.form {
            if let data = httpModel?.requestData {
                //1.protobuf
//                if let message = try? GPBMessage.parse(from: data) {
//                    if message.serializedSize() > 0 {
//                        requestContent = message.description
//                    } else {
                        //2.Form
                        requestContent = data.dataToString()
//                    }
//                }
                if requestContent == nil || requestContent == "" || requestContent == "\u{8}\u{1e}" {
                    //3.utf-8 string
                    requestContent = String(data: data, encoding: .utf8)
                }
                if requestContent == "" || requestContent == "\u{8}\u{1e}" {
                    requestContent = nil
                }
            }
        }
        
        if httpModel?.isImage == true {
            //image:
            //1.
            let model_1 = NetworkDetailModel.init(title: "URL", content: "https://github.com/CocoaDebug/CocoaDebug", url: httpModel?.url.absoluteString, httpModel: httpModel)
            let model_3 = NetworkDetailModel.init(title: "REQUEST", content: requestContent, url: httpModel?.url.absoluteString, httpModel: httpModel)
            var model_5 = NetworkDetailModel.init(title: "RESPONSE", content: nil, url: httpModel?.url.absoluteString, httpModel: httpModel)
            let model_6 = NetworkDetailModel.init(title: "ERROR", content: httpModel?.errorLocalizedDescription, url: httpModel?.url.absoluteString, httpModel: httpModel)
            let model_7 = NetworkDetailModel.init(title: "ERROR DESCRIPTION", content: httpModel?.errorDescription, url: httpModel?.url.absoluteString, httpModel: httpModel)
            if let responseData = httpModel?.responseData {
                model_5 = NetworkDetailModel.init(title: "RESPONSE", content: nil, url: httpModel?.url.absoluteString, image: UIImage.init(gifData: responseData), httpModel: httpModel)
                // For images, completeResponseContent remains nil (not needed for copy/email)
            }
            //2.
            let model_8 = NetworkDetailModel.init(title: "TOTAL TIME", content: httpModel?.totalDuration, url: httpModel?.url.absoluteString, httpModel: httpModel)
            let model_9 = NetworkDetailModel.init(title: "MIME TYPE", content: httpModel?.mineType, url: httpModel?.url.absoluteString, httpModel: httpModel)
            var model_2 = NetworkDetailModel.init(title: "REQUEST HEADER", content: nil, url: httpModel?.url.absoluteString, httpModel: httpModel)
            if let requestHeaderFields = httpModel?.requestHeaderFields {
                if !requestHeaderFields.isEmpty {
                    model_2 = NetworkDetailModel.init(title: "REQUEST HEADER", content: requestHeaderFields.description, url: httpModel?.url.absoluteString, httpModel: httpModel)
                    model_2.requestHeaderFields = requestHeaderFields
                    model_2.content = String(requestHeaderFields.dictionaryToString()?.dropFirst().dropLast().dropFirst().dropLast().dropFirst().dropFirst() ?? "").replacingOccurrences(of: "\",\n  \"", with: "\",\n\"").replacingOccurrences(of: "\\/", with: "/")
                }
            }
            var model_4 = NetworkDetailModel.init(title: "RESPONSE HEADER", content: nil, url: httpModel?.url.absoluteString, httpModel: httpModel)
            if let responseHeaderFields = httpModel?.responseHeaderFields {
                if !responseHeaderFields.isEmpty {
                    model_4 = NetworkDetailModel.init(title: "RESPONSE HEADER", content: responseHeaderFields.description, url: httpModel?.url.absoluteString, httpModel: httpModel)
                    model_4.responseHeaderFields = responseHeaderFields
                    model_4.content = String(responseHeaderFields.dictionaryToString()?.dropFirst().dropLast().dropFirst().dropLast().dropFirst().dropFirst() ?? "").replacingOccurrences(of: "\",\n  \"", with: "\",\n\"").replacingOccurrences(of: "\\/", with: "/")
                }
            }
            let model_0 = NetworkDetailModel.init(title: "RESPONSE SIZE", content: httpModel?.size, url: httpModel?.url.absoluteString, httpModel: httpModel)
            //3.
            detailModels.append(model_1)
            detailModels.append(model_2)
            detailModels.append(model_3)
            detailModels.append(model_4)
            detailModels.append(model_5)
            detailModels.append(model_6)
            detailModels.append(model_7)
            detailModels.append(model_0)
            detailModels.append(model_8)
            detailModels.append(model_9)
        }
        else {
            //not image:
            //1.
            let model_1 = NetworkDetailModel.init(title: "URL", content: "https://github.com/CocoaDebug/CocoaDebug", url: httpModel?.url.absoluteString, httpModel: httpModel)
            let model_3 = NetworkDetailModel.init(title: "REQUEST", content: requestContent, url: httpModel?.url.absoluteString, httpModel: httpModel)
            
            // Split RESPONSE content into chunks if it's long
            let responseContent = httpModel?.responseData.dataToPrettyPrintString()
            // Store complete response for copy/email
            completeResponseContent = responseContent
            let responseModels = createChunkedModels(for: responseContent, title: "RESPONSE", url: httpModel?.url.absoluteString, httpModel: httpModel)
            
            let model_6 = NetworkDetailModel.init(title: "ERROR", content: httpModel?.errorLocalizedDescription, url: httpModel?.url.absoluteString, httpModel: httpModel)
            let model_7 = NetworkDetailModel.init(title: "ERROR DESCRIPTION", content: httpModel?.errorDescription, url: httpModel?.url.absoluteString, httpModel: httpModel)
            //2.
            let model_8 = NetworkDetailModel.init(title: "TOTAL TIME", content: httpModel?.totalDuration, url: httpModel?.url.absoluteString, httpModel: httpModel)
            let model_9 = NetworkDetailModel.init(title: "MIME TYPE", content: httpModel?.mineType, url: httpModel?.url.absoluteString, httpModel: httpModel)
            var model_2 = NetworkDetailModel.init(title: "REQUEST HEADER", content: nil, url: httpModel?.url.absoluteString, httpModel: httpModel)
            if let requestHeaderFields = httpModel?.requestHeaderFields {
                if !requestHeaderFields.isEmpty {
                    model_2 = NetworkDetailModel.init(title: "REQUEST HEADER", content: requestHeaderFields.description, url: httpModel?.url.absoluteString, httpModel: httpModel)
                    model_2.requestHeaderFields = requestHeaderFields
                    model_2.content = String(requestHeaderFields.dictionaryToString()?.dropFirst().dropLast().dropFirst().dropLast().dropFirst().dropFirst() ?? "").replacingOccurrences(of: "\",\n  \"", with: "\",\n\"").replacingOccurrences(of: "\\/", with: "/")
                }
            }
            var model_4 = NetworkDetailModel.init(title: "RESPONSE HEADER", content: nil, url: httpModel?.url.absoluteString, httpModel: httpModel)
            if let responseHeaderFields = httpModel?.responseHeaderFields {
                if !responseHeaderFields.isEmpty {
                    model_4 = NetworkDetailModel.init(title: "RESPONSE HEADER", content: responseHeaderFields.description, url: httpModel?.url.absoluteString, httpModel: httpModel)
                    model_4.responseHeaderFields = responseHeaderFields
                    model_4.content = String(responseHeaderFields.dictionaryToString()?.dropFirst().dropLast().dropFirst().dropLast().dropFirst().dropFirst() ?? "").replacingOccurrences(of: "\",\n  \"", with: "\",\n\"").replacingOccurrences(of: "\\/", with: "/")
                }
            }
            let model_0 = NetworkDetailModel.init(title: "RESPONSE SIZE", content: httpModel?.size, url: httpModel?.url.absoluteString, httpModel: httpModel)
            //3.
            detailModels.append(model_1)
            detailModels.append(model_2)
            detailModels.append(model_3)
            detailModels.append(model_4)
            // Append all response chunks
            detailModels.append(contentsOf: responseModels)
            detailModels.append(model_6)
            detailModels.append(model_7)
            detailModels.append(model_0)
            detailModels.append(model_8)
            detailModels.append(model_9)
        }
    }
    
    //detetc request format (JSON/Form)
    func detectRequestSerializer() {
        guard let requestData = httpModel?.requestData else {
            httpModel?.requestSerializer = RequestSerializer.JSON//default JSON format
            return
        }
        
        if let _ = requestData.dataToDictionary() {
            //JSON format
            httpModel?.requestSerializer = RequestSerializer.JSON
        } else {
            //Form format
            httpModel?.requestSerializer = RequestSerializer.form
        }
    }
    
    
    //email configure
    func configureMailComposer(_ copy: Bool = false) -> MFMailComposeViewController? {
        
        //1.image
        var img: UIImage? = nil
        var isImage: Bool = false
        if let httpModel = httpModel {
            isImage = httpModel.isImage
        }
        
        //2.body message ------------------ start ------------------
        var string: String = ""
        messageBody = ""
        
        //unfilteredModels, NOT detailModels: with a search active detailModels is only the
        //matching sections, and exporting from that silently ships a truncated report into
        //whatever bug ticket this ends up in
        for model in unfilteredModels {
            if let title = model.title {
                // For RESPONSE, use the complete response content instead of chunked content
                if title == "RESPONSE", let completeResponse = completeResponseContent, completeResponse != "" {
                    string = "\n\n" + "------- " + title + " -------" + "\n" + completeResponse
                } else if let content = model.content, content != "" {
                    string = "\n\n" + "------- " + title + " -------" + "\n" + content
                }
                
                if !messageBody.contains(string) {
                    messageBody.append(string)
                }
            }
            //image
            if isImage == true {
                if let image = model.image {
                    img = image
                }
            }
        }
        
        //2.1.url
        var url: String = ""
        if let httpModel = httpModel {
            url = httpModel.url.absoluteString
        }
        
        //2.2.method
        var method: String = ""
        if let httpModel = httpModel {
            method = "[" + httpModel.method + "]"
        }
        
        //2.3.time
        var time: String = ""
        if let httpModel = httpModel {
            if let startTime = httpModel.startTime {
                if (startTime as NSString).doubleValue == 0 {
                    time = _OCLoggerFormat.formatDate(Date())
                } else {
                    time = _OCLoggerFormat.formatDate(NSDate(timeIntervalSince1970: (startTime as NSString).doubleValue) as Date)
                }
            }
        }
        
        //2.4.statusCode
        var statusCode: String = ""
        if let httpModel = httpModel {
            statusCode = httpModel.statusCode
            if statusCode == "0" { //"0" means network unavailable
                statusCode = "❌"
            }
        }
        
        //body message ------------------ end ------------------
        var subString = method + " " + time + " " + "(" + statusCode + ")"
        if subString.contains("❌") {
            subString = subString.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        }
        
        messageBody = messageBody.replacingOccurrences(of: "https://github.com/CocoaDebug/CocoaDebug", with: url)
        messageBody = subString + messageBody
        
        //////////////////////////////////////////////////////////////////////////////////
        
        if !MFMailComposeViewController.canSendMail() {
            if copy == false {
                //share via email
                let alert = UIAlertController.init(title: "No Mail Accounts", message: "Please set up a Mail account in order to send email.", preferredStyle: .alert)
                let action = UIAlertAction.init(title: "OK", style: .cancel) { _ in
                }
                alert.addAction(action)
                
                alert.popoverPresentationController?.permittedArrowDirections = .init(rawValue: 0)
                alert.popoverPresentationController?.sourceView = self.view
                alert.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                
                self.present(alert, animated: true, completion: nil)
            } else {
                //copy to clipboard
            }
            
            return nil
        }
        
        if copy == true {
            //copy to clipboard
            return nil
        }
        
        //3.email recipients
        let mailComposeVC = MFMailComposeViewController()
        mailComposeVC.mailComposeDelegate = self
        mailComposeVC.setToRecipients(CocoaDebugSettings.shared.emailToRecipients)
        mailComposeVC.setCcRecipients(CocoaDebugSettings.shared.emailCcRecipients)
        
        //4.image
        if let img = img {
            if let imageData = img.pngData() {
                mailComposeVC.addAttachmentData(imageData, mimeType: "image/png", fileName: "image")
            }
        }
        
        //5.body
        mailComposeVC.setMessageBody(messageBody, isHTML: false)
        
        //6.subject
        mailComposeVC.setSubject(url)
        
        return mailComposeVC
    }
    
    
    //MARK: - init
    override func viewDidLoad() {
        super.viewDidLoad()
        
        naviItemTitleLabel = UILabel.init(frame: CGRect(x: 0, y: 0, width: 80, height: 40))
        naviItemTitleLabel?.textAlignment = .center
        naviItemTitleLabel?.textColor = Color.mainGreen
        naviItemTitleLabel?.font = .boldSystemFont(ofSize: 20)
        naviItemTitleLabel?.text = "Details"
        naviItem.titleView = naviItemTitleLabel
        
        closeItem.tintColor = Color.mainGreen
        cURLItem.tintColor = Color.mainGreen
        
        //detect the request format (JSON/Form)
        detectRequestSerializer()
        
        setupModels()
        
        if var lastModel = detailModels.last {
            lastModel.isLast = true
            detailModels.removeLast()
            detailModels.append(lastModel)
        }

        unfilteredModels = detailModels

        //dragging the list dismisses the keyboard, as does the keyboard's own Search key
        //(searchBarSearchButtonClicked); clearing the query is the field's clear button
        tableView.keyboardDismissMode = .onDrag

        //iOS 15+ inserts padding above every plain-style section header, which showed up as a
        //gap above the search bar now that the bar lives in the header
        tableView.sectionHeaderTopPadding = 0

        //Use a separate xib-cell file, must be registered, otherwise it will crash
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "NetworkCell", bundle: bundle)
        tableView.register(nib, forCellReuseIdentifier: "NetworkCell")
        
        //header
        headerCell = bundle.loadNibNamed(String(describing: NetworkCell.self), owner: nil, options: nil)?.first as? NetworkCell
        headerCell?.httpModel = httpModel

        setupHeaderContainer()
        
        // Configure automatic height calculation for long content
        tableView.estimatedRowHeight = 200
        tableView.rowHeight = UITableView.automaticDimension
        
        // Improve scrolling performance
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
    }
    
    //Search bar, match label and the URL/status block stacked into the floating section
    //header (see the searchBar comment for why it lives there). Built once, so
    //viewForHeaderInSection only has to hand the container back.
    private func setupHeaderContainer() {
        guard let content = headerCell?.contentView else {return}

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        matchLabel.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(searchBar)
        headerContainer.addSubview(matchLabel)
        headerContainer.addSubview(content)

        let matchHeight = matchLabel.heightAnchor.constraint(equalToConstant: 0)
        matchBarHeightConstraint = matchHeight

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: searchBarHeight),

            matchLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            matchLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 12),
            matchLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerContainer.trailingAnchor, constant: -12),
            matchHeight,

            content.topAnchor.constraint(equalTo: matchLabel.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor)
        ])

        updateMatchBar()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let index = httpModels?.firstIndex(where: { (model) -> Bool in
            return model.isSelected == true
        }) {
            httpModels?[index].isSelected = false
        }
        
        httpModel?.isSelected = true
        
        if let justCancelCallback = justCancelCallback {
            justCancelCallback()
        }
    }
    
    //MARK: - search
    //ONE pass over the sections: a section is kept when its content has at least one match, and
    //that same scan feeds the counter. Filtering, counting and the cell's highlighting now all
    //come from NetworkDetailCell.ranges(of:in:) over the same `content`, so the visible rows
    //and the "N matches" label cannot contradict each other.
    //
    //Titles are deliberately NOT a predicate: they are never highlighted, so a title match
    //showed a section that the counter — and the cell — found nothing in.
    @objc private func applySearch() {
        matchCount = 0

        if searchQuery.isEmpty {
            detailModels = unfilteredModels
        } else {
            //row 0 is the height-0 URL row the header cell renders: always kept, never counted
            //(a match there would be reported but could never be scrolled to)
            var kept = Array(unfilteredModels.prefix(1))

            for model in unfilteredModels.dropFirst() {
                let hits = NetworkDetailCell.ranges(of: searchQuery, in: model.content ?? "").count
                if hits > 0 {
                    matchCount += hits
                    kept.append(model)
                }
            }

            //isLast draws the closing divider and was stamped on the last UNFILTERED model, so
            //the last VISIBLE row lost its bottom line whenever a filter was active
            for index in kept.indices {
                kept[index].isLast = (index == kept.count - 1)
            }

            detailModels = kept
        }

        updateMatchBar()
        tableView.reloadData()
    }

    private func updateMatchBar() {
        matchBarHeightConstraint?.constant = searchQuery.isEmpty ? 0 : matchBarHeight
        matchLabel.isHidden = searchQuery.isEmpty

        if searchQuery.isEmpty {
            matchLabel.text = nil
        } else if matchCount == 0 {
            matchLabel.text = "No matches"
        } else {
            matchLabel.text = matchCount == 1 ? "1 match" : "\(matchCount) matches"
        }
    }

    //MARK: - target action
    @IBAction func close(_ sender: UIBarButtonItem) {
        (self.navigationController as! CocoaDebugNavigationController).exit()
    }
    
    @IBAction func curlAction(_ sender: Any) {
        var curlCommand = "curl"
        
        if let method = httpModel?.method {
            curlCommand += " -X \(method)"
        }
        
        if let url = httpModel?.url?.absoluteString {
            curlCommand += " \(url)"
        }
        
        if let headers = httpModel?.requestHeaderFields {
            let formattedHeaderString = headers.formattedCurlString()
            curlCommand += " -H \(formattedHeaderString)"
        }
        
        
        if let requestData = httpModel?.requestData?.formattedCurlString(), requestData != "" {
            curlCommand += " -d \(requestData)"
        }
        
        UIPasteboard.general.string = curlCommand
    }
    
    @IBAction func didTapMail(_ sender: UIBarButtonItem) {
        
        // create an actionSheet
        let alert: UIAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // create an action
        let firstAction: UIAlertAction = UIAlertAction(title: "share via email", style: .default) { [weak self] action -> Void in
            if let mailComposeViewController = self?.configureMailComposer() {
                self?.present(mailComposeViewController, animated: true, completion: nil)
            }
        }
        
        let secondAction: UIAlertAction = UIAlertAction(title: "copy to clipboard", style: .default) { [weak self] action -> Void in
            _ = self?.configureMailComposer(true)
            UIPasteboard.general.string = self?.messageBody
        }
        
        let moreAction: UIAlertAction = UIAlertAction(title: "more", style: .default) { [weak self] action -> Void in
            _ = self?.configureMailComposer(true)
            let items: [Any] = [self?.messageBody ?? ""]
            let action = UIActivityViewController(activityItems: items, applicationActivities: nil)
            if UI_USER_INTERFACE_IDIOM() == .phone {
                self?.present(action, animated: true, completion: nil)
            } else {
                action.popoverPresentationController?.sourceRect = .init(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 0, height: 0)
                action.popoverPresentationController?.sourceView = self?.view
                self?.present(action, animated: true, completion: nil)
            }

        }
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
        }
        
        // add actions
        alert.addAction(secondAction)
        alert.addAction(firstAction)
        alert.addAction(moreAction)
        alert.addAction(cancelAction)
        
        alert.popoverPresentationController?.permittedArrowDirections = .init(rawValue: 0)
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        
        // present an actionSheet...
        present(alert, animated: true, completion: nil)
    }
}

//MARK: - UISearchBarDelegate
extension NetworkDetailViewController: UISearchBarDelegate {

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        //trimmed only for the EMPTINESS test — whitespace is meaningful inside the query
        //itself, since pretty-printed JSON is full of ": " and indentation worth searching for
        searchQuery = searchText.trimmingCharacters(in: .whitespaces).isEmpty ? "" : searchText

        //a full content scan plus reloadData on every keystroke stutters on a multi-megabyte
        //response, so coalesce the typing. Clearing stays immediate.
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(applySearch), object: nil)

        if searchQuery.isEmpty {
            applySearch()
        } else {
            perform(#selector(applySearch), with: nil, afterDelay: 0.25)
        }
    }
}

//MARK: - UITableViewDataSource
extension NetworkDetailViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detailModels.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NetworkDetailCell", for: indexPath)
            as! NetworkDetailCell
        
        let detailModel = detailModels[indexPath.row]
        cell.detailModel = detailModel
        cell.highlight(searchQuery)

        // Hide top line divider for response chunks (after the first one) - set after detailModel
        let isResponseChunk = detailModel.blankContent == "response_chunk"
        cell.hideTopLine = isResponseChunk
        
        // Click edit view
        cell.tapEditViewCallback = { [weak self] detailModel in
            let vc = JsonViewController.instanceFromStoryBoard()
            vc.detailModel = detailModel
            self?.navigationController?.pushViewController(vc, animated: true)
        }
        
        return cell
    }
}

//MARK: - UITableViewDelegate
extension NetworkDetailViewController {
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let detailModel = detailModels[indexPath.row]
        
        // Handle blank content rows with fixed height
        if detailModel.blankContent == "..." {
            if detailModel.isLast == true {
                return 50.5
            }
            return 50
        }
        
        // Handle first row
        if indexPath.row == 0 {
            return 0
        }
        
        // Handle image rows with fixed height
        if detailModel.image != nil {
            return UIScreen.main.bounds.size.width + 50
        }
        
        // Handle empty content
        if let content = detailModel.content, content.isEmpty {
            return 0
        }
        
        // For all text content, use automatic dimension
        return UITableView.automaticDimension
    }
    
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerContainer
    }
    
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let detailModel = detailModels[indexPath.row]
        let isResponseChunk = detailModel.blankContent == "response_chunk"
        
        // Remove spacing between response chunk cells
        if isResponseChunk {
            // Hide separator and remove margins for seamless appearance
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
            cell.layoutMargins = .zero
            cell.preservesSuperviewLayoutMargins = false
            cell.contentView.layoutMargins = .zero
        } else {
            // Reset to default for non-chunk cells
            cell.separatorInset = UIEdgeInsets.zero
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        //the search bar is part of this header, so it must be counted even when the URL
        //block measures to 0 — otherwise the header collapses and the search bar vanishes
        return urlHeaderHeight() + searchBarHeight + (searchQuery.isEmpty ? 0 : matchBarHeight)
    }

    private func urlHeaderHeight() -> CGFloat {
        guard let serverURL = CocoaDebugSettings.shared.serverURL else {return 0}
        
        var height: CGFloat = 0.0
        
        if let cString = httpModel?.url.absoluteString.cString(using: String.Encoding.utf8) {
            if let content_ = NSString(cString: cString, encoding: String.Encoding.utf8.rawValue) {
                
                //the request's own server URL is drawn heavier than a third-party one.
                //The old #available(iOS 8.2) fallbacks are gone: the pod's deployment target
                //is 15.0, so they could never be taken.
                let weight: UIFont.Weight = httpModel?.url.absoluteString.contains(serverURL) == true ? .heavy : .regular
                height = content_.height(with: UIFont.systemFont(ofSize: 13, weight: weight),
                                         constraintToWidth: (UIScreen.main.bounds.size.width - 92))
                return height + 57
            }
        }
        
        return 0
    }
}

//MARK: - MFMailComposeViewControllerDelegate
extension NetworkDetailViewController {
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        
        controller.dismiss(animated: true) {
            if error != nil {
                let alert = UIAlertController.init(title: error?.localizedDescription, message: nil, preferredStyle: .alert)
                let action = UIAlertAction.init(title: "OK", style: .cancel, handler: { _ in
                })
                alert.addAction(action)
                
                alert.popoverPresentationController?.permittedArrowDirections = .init(rawValue: 0)
                alert.popoverPresentationController?.sourceView = self.view
                alert.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}

extension [String: Any] {
    func formattedCurlString() -> String {
        return map { key, value in
            "\'\(key): \(value)\'"
        }.joined(separator: " -H ")
    }
}

extension Data {
    func formattedCurlString() -> String {
        if let string = String(data: self, encoding: .utf8) {
            return string.escapedForCurl()
        }
        return ""
    }
}

extension String {
    func escapedForCurl() -> String {
        replacingOccurrences(of: "'", with: "\\'")
    }
}
