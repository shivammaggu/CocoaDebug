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
