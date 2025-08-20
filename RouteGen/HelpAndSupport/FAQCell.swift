//
//  FAQCell.swift
//  RouteGen
//
//  Created by 10167 on 21/7/2025.
//

import UIKit

class FAQCell: UITableViewCell {
    
    @IBOutlet weak var questionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        
        
        isUserInteractionEnabled = true
        contentView.isUserInteractionEnabled = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.backgroundColor = .white
    }
}
