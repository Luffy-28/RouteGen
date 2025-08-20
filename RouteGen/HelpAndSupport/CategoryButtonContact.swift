//
//  categoryButtonContact.swift
//  RouteGen
//
//  Created by 10167 on 22/7/2025.
//
import Foundation
import UIKit

class CategoryButtonContact: UIButton{
    
    // MARK: - Properties
    private let categories = [
        "Technical Issues",
        "Account & Billing",
        "Feature Request",
        "Bug Report",
        "General Inquiry"
    ]
    
    private(set) var selectedCategory: String?
    
    // Callback when category is selected
    var onCategorySelected: ((String) -> Void)?
    
    // MARK: - Initialization
    override func awakeFromNib() {
        super.awakeFromNib()
        setupMenu()
        
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.systemGray4.cgColor
        self.layer.cornerRadius = 8
    }
    
    // MARK: - Setup
    private func setupMenu() {
        var menuActions: [UIAction] = []
        
        // Create menu actions for each category
        for category in categories {
            let action = UIAction(title: category) { [weak self] _ in
                self?.didSelectCategory(category)
            }
            menuActions.append(action)
        }
        
        // Create and assign menu
        let menu = UIMenu(title: "", children: menuActions)
        self.menu = menu
        self.showsMenuAsPrimaryAction = true
        
        // Force downward direction (iOS 16+)
        if #available(iOS 16.0, *) {
            self.preferredMenuElementOrder = .fixed
            self.changesSelectionAsPrimaryAction = false
        }
    }
    
    // MARK: - Actions
    private func didSelectCategory(_ category: String) {
        selectedCategory = category
        
        // Update button title
        self.setTitle(category, for: .normal)
        
        // Notify delegate/callback
        onCategorySelected?(category)
    }
    
    // MARK: - Public Methods
    func reset() {
        selectedCategory = nil
        self.setTitle("Select a category", for: .normal)
    }
    
    func getSelectedCategory() -> String? {
        return selectedCategory
    }
}
