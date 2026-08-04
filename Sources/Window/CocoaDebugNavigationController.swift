//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import UIKit

class CocoaDebugNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationBar.isTranslucent = false //liman
        
        navigationBar.tintColor = Color.mainGreen
        navigationBar.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                             .foregroundColor: Color.mainGreen]
        
        let selector = #selector(CocoaDebugNavigationController.exit)
        
        let image = UIImage(named: "_icon_file_type_close", in: Bundle(for: CocoaDebugNavigationController.self), compatibleWith: nil)
        let leftItem = UIBarButtonItem(image: image,
                                       style: .done, target: self, action: selector)
        leftItem.tintColor = Color.mainGreen
        if #available(iOS 26.0, *) {
            leftItem.hidesSharedBackground = true    //iOS 26: kill Liquid Glass capsule on button
        }
        // Prepend the close button WITHOUT clobbering the storyboard's leading items.
        // Assigning `leftBarButtonItem` replaces the first item (killing e.g. the Network
        // screen's up-scroll button); insert at index 0 to preserve all existing items.
        if let navItem = topViewController?.navigationItem {
            var items = navItem.leftBarButtonItems ?? []
            if items.first?.action != selector {
                items.insert(leftItem, at: 0)
                navItem.leftBarButtonItems = items
            }
        }

        //bugfix #issues-158
        if #available(iOS 13, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = "#1f2124".hexColor    //iOS 26: force opaque bg so bar doesn't fall back to Liquid Glass
            // self.navigationController?.navigationBar.isTranslucent = true  // pass "true" for fixing iOS 15.0 black bg issue
            // self.navigationController?.navigationBar.tintColor = UIColor.white // We need to set tintcolor for iOS 15.0
            appearance.shadowColor = .clear    //removing navigationbar 1 px bottom border.
//            UINavigationBar.appearance().standardAppearance = appearance
//            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            self.navigationBar.standardAppearance = appearance
            self.navigationBar.scrollEdgeAppearance = appearance
            self.navigationBar.compactAppearance = appearance
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //iOS 26: strip Liquid Glass capsule from every bar button item (incl. storyboard-set items
        //like the Network screen's up/hammer/trash). Idempotent; safe to run each layout pass.
        if #available(iOS 26.0, *) {
            let item = topViewController?.navigationItem
            let all = (item?.leftBarButtonItems ?? []) + (item?.rightBarButtonItems ?? [])
            for barButton in all where !barButton.hidesSharedBackground {
                barButton.hidesSharedBackground = true
            }
        }
    }


    @objc func exit() {
        dismiss(animated: true, completion: nil)
    }
}
