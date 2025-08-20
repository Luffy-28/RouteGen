//
//  HelpAndSupportVC.swift
//  RouteGen
//
//  Created by 10167 on 21/7/2025.
//
import Foundation
import UIKit

// MARK: - HelpAndSupportVC
class HelpAndSupportVC: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var subjectTF: UITextField!
    @IBOutlet weak var messageTF: UITextView!
    @IBOutlet weak var categoryButton: CategoryButtonContact!
    
    /// Your list of questions & answers
    private let faqs: [(question: String, answer: String)] = [
        ("How do I create my first route?", "To create your first route, open the app and tap 'Create' in the tabBar. Enter your distance or address, then tap 'Generate Route'. The app will create an optimized path for you."),
        ("Can I save my favorite routes?", "Yes. After you generate a route, simply tap the button at the top of the screen to save it to your Favorites list."),
        ("How does the leaderboard work?", "The leaderboard shows your ranking compared to other users based on miles traveled"),
        ("The GPS stopped working?", "First, ensure location services are enabled for the app in Settings. Try restarting the app or your device. If issues persist, check for app updates."),
        ("How can I change my account details?", "Go to Settings > Edit Profile. From there you can update your profile, email, and preferences."),
    ]
    
    /// Track which question index is currently expanded
    private var expandedQuestionIndex: Int? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        setUpCategoryPicker()
        setupUI()
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        
        // Disable nested scrolling
        tableView.isScrollEnabled = false
        tableView.allowsSelection = true
        
        // Automatic cell height
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        
        // Clean up empty separators
        tableView.tableFooterView = UIView()
        // Add bottom padding to ensure last answer is visible
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
    }
    
    private func setUpCategoryPicker() {
        // Setup category button callback
        categoryButton.onCategorySelected = { [weak self] category in
            print("Category selected: \(category)")
           
        }
    }
    
    private func setupUI() {
            messageTF.layer.borderWidth = 1
            messageTF.layer.borderColor = UIColor.systemGray4.cgColor
            messageTF.layer.cornerRadius = 8
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Actions
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        // Test that we can get the form data
        print("Send button tapped")
        
        if let selectedCategory = categoryButton.getSelectedCategory() {
            print("Selected category: \(selectedCategory)")
            print("Subject: \(subjectTF.text ?? "")")
            print("Message: \(messageTF.text ?? "")")
            subjectTF.text = ""
            messageTF.text = ""
        } else {
            print("No category selected")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableHeight()
    }
    
    private func updateTableHeight() {
        tableView.layoutIfNeeded()
        let height = tableView.contentSize.height + 50
        tableViewHeightConstraint.constant = height
        view.layoutIfNeeded()
    }
}

// MARK: - UITableViewDataSource
extension HelpAndSupportVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Count questions + 1 extra row for expanded answer
        let questionCount = faqs.count
        let expandedRows = expandedQuestionIndex != nil ? 1 : 0
        return questionCount + expandedRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Determine if this row is a question or answer
        var currentFAQIndex = 0
        var currentRow = 0
        
        while currentRow < indexPath.row && currentFAQIndex < faqs.count {
            if expandedQuestionIndex == currentFAQIndex {
                // This FAQ is expanded, skip 2 rows (question + answer)
                currentRow += 2
            } else {
                // This FAQ is collapsed, skip 1 row
                currentRow += 1
            }
            if currentRow <= indexPath.row {
                currentFAQIndex += 1
            }
        }
        
        // Check if this is an answer row
        if expandedQuestionIndex == currentFAQIndex && currentRow - 1 == indexPath.row {
            // This is an answer row
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "AnswerCell", for: indexPath) as? AnswerCell else {
                return UITableViewCell()
            }
            
            let answer = faqs[currentFAQIndex].answer
            cell.configure(with: answer)
            return cell
        }
        
        // This is a question row
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FAQCell", for: indexPath) as? FAQCell else {
            return UITableViewCell()
        }
        
        if currentFAQIndex < faqs.count {
            let faq = faqs[currentFAQIndex]
            cell.questionLabel.text = faq.question
            
            // Visual feedback for expanded state
            let isExpanded = expandedQuestionIndex == currentFAQIndex
            cell.contentView.backgroundColor = isExpanded ? UIColor.systemGray5 : UIColor.white
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension HelpAndSupportVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Determine which FAQ was tapped
        var currentFAQIndex = 0
        var currentRow = 0
        
        while currentRow < indexPath.row && currentFAQIndex < faqs.count {
            if expandedQuestionIndex == currentFAQIndex {
                // This FAQ is expanded
                if currentRow + 1 == indexPath.row {
                    // User tapped on an answer row, ignore
                    return
                }
                currentRow += 2
            } else {
                currentRow += 1
            }
            if currentRow <= indexPath.row {
                currentFAQIndex += 1
            }
        }
        
        // Ignore if we somehow got an invalid index
        guard currentFAQIndex < faqs.count else { return }
        
        print("Tapped FAQ index: \(currentFAQIndex)")
        
        // Simple approach: just reload the whole table with animation
        tableView.performBatchUpdates({
            if expandedQuestionIndex == currentFAQIndex {
                // Collapse
                expandedQuestionIndex = nil
            } else {
                // Expand new (and implicitly collapse old)
                expandedQuestionIndex = currentFAQIndex
            }
            
            // Reload all data
            tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        }) { _ in
            // Update table height after animation
            self.updateTableHeight()
        }
    }
    
    // Optional: Customize row heights
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Determine if this is an answer row using the same logic as cellForRowAt
        var currentFAQIndex = 0
        var currentRow = 0
        
        while currentRow < indexPath.row && currentFAQIndex < faqs.count {
            if expandedQuestionIndex == currentFAQIndex {
                currentRow += 2
            } else {
                currentRow += 1
            }
            if currentRow <= indexPath.row {
                currentFAQIndex += 1
            }
        }
        
        // Check if this is an answer row
        if expandedQuestionIndex == currentFAQIndex && currentRow - 1 == indexPath.row {
            return UITableView.automaticDimension  // Let answer size itself
        }
        
        return 60  // Fixed height for questions
    }
}
