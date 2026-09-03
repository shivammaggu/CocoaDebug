//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import Foundation
import UIKit

class NetworkDetailCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentTextView: CustomTextView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var topLine: UIView!
    @IBOutlet weak var middleLine: UIView!
    @IBOutlet weak var bottomLine: UIView!
    @IBOutlet weak var editView: UIView!
    
    @IBOutlet weak var contextTextTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewBottomSpaceToMiddleLine: NSLayoutConstraint!
    //-12.5
    
    var hideTopLine: Bool = false {
        didSet {
            topLine.isHidden = hideTopLine
        }
    }
    
    var tapEditViewCallback:((NetworkDetailModel?) -> Void)?

    //captured once: assigning attributedText can overwrite the text view's own font/textColor,
    //and the storyboard values are the only record of them (white-on-black would go black-on-black)
    private var baseFont: UIFont?
    private var baseTextColor: UIColor?

    var detailModel: NetworkDetailModel? {
        didSet {
            
            titleLabel.text = detailModel?.title
            contentTextView.text = detailModel?.content
            
            // Disable scrolling - we use table view scrolling with dynamic height
            contentTextView.isScrollEnabled = false
            
            //image
            if detailModel?.image == nil {
                imgView.isHidden = true
            } else {
                imgView.isHidden = false
                imgView.image = detailModel?.image
            }
            
            // Hide title view and divider for response chunks (no header)
            let isResponseChunk = detailModel?.blankContent == "response_chunk"
            let hasNoTitle = detailModel?.title == nil || detailModel?.title?.isEmpty == true
            
            if hasNoTitle || isResponseChunk {
                // Hide header for chunks and remove spacing
                titleView.isHidden = true
                middleLine.isHidden = true
                // topLine visibility is controlled by hideTopLine property (set externally)
                titleViewBottomSpaceToMiddleLine.constant = 0
                
                // Remove top spacing/padding for response chunks
                contentTextView.textContainerInset = UIEdgeInsets.zero
                contextTextTopConstraint.isActive = true
            } else if detailModel?.blankContent == "..." {
                // Hide content automatically
                middleLine.isHidden = true
                imgView.isHidden = true
                titleViewBottomSpaceToMiddleLine.constant = -12.5 + 2
            } else {
                // Normal content with title
                titleView.isHidden = false
                middleLine.isHidden = false
                topLine.isHidden = false
                if detailModel?.image != nil {
                    imgView.isHidden = false
                }
                titleViewBottomSpaceToMiddleLine.constant = 0
                contextTextTopConstraint.isActive = false
            }
            
            //Bottom dividing line
            if detailModel?.isLast == true {
                bottomLine.isHidden = false
            } else {
                bottomLine.isHidden = true
            }
        }
    }
    
    //MARK: - awakeFromNib
    override func awakeFromNib() {
        super.awakeFromNib()
        
        editView.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(tapEditView)))

        baseFont = contentTextView.font
        baseTextColor = contentTextView.textColor

        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.textContainerInset = .zero
        contentTextView.isScrollEnabled = false
        
        // Optimize for better performance
        contentTextView.layoutManager.allowsNonContiguousLayout = true
        
        // Remove default cell spacing
        separatorInset = UIEdgeInsets.zero
        layoutMargins = .zero
        preservesSuperviewLayoutMargins = false
    }
    
    
    //MARK: - search highlighting
    //Call after assigning detailModel. Every occurrence of `query` in the content gets a
    //highlight; an empty query restores the plain rendering.
    func highlight(_ query: String) {
        guard let content = detailModel?.content, !content.isEmpty else {return}

        let base: [NSAttributedString.Key: Any] = [
            .font: baseFont ?? contentTextView.font ?? UIFont.systemFont(ofSize: 13),
            .foregroundColor: baseTextColor ?? contentTextView.textColor ?? .white
        ]

        guard !query.isEmpty else {
            //restore: detailModel's setter already assigned .text, but a previous
            //attributedText may have left the font/colour on the matched word
            contentTextView.attributedText = NSAttributedString(string: content, attributes: base)
            return
        }

        let attributed = NSMutableAttributedString(string: content, attributes: base)
        let nsContent = content as NSString
        var searchRange = NSRange(location: 0, length: nsContent.length)

        while searchRange.length > 0 {
            let found = nsContent.range(of: query, options: .caseInsensitive, range: searchRange)
            if found.location == NSNotFound {break}

            attributed.addAttributes([.backgroundColor: UIColor.systemYellow,
                                      .foregroundColor: UIColor.black], range: found)

            let next = found.location + found.length
            searchRange = NSRange(location: next, length: nsContent.length - next)
        }

        contentTextView.attributedText = attributed
    }

    //MARK: - target action
    //edit
    @objc func tapEditView() {
        if let tapEditViewCallback = tapEditViewCallback {
            tapEditViewCallback(detailModel)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
