//
//  AnswerCell.swift
//  RouteGen
//
//  Created by 10167 on 22/7/2025.
//

import Foundation
import UIKit

class AnswerCell: UITableViewCell {
    
    @IBOutlet weak var answerLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        
       
        
        
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }
    
    func configure(with answer: String) {
        answerLabel.text = answer
    }
}
