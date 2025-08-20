//
//  PurchaseCell.swift
//  RouteGen
//
//  Created by Shankar Singh on 13/8/2025.
//

import UIKit

class PurchaseCell: UITableViewCell {
    @IBOutlet weak var purchaseDateLabel: UILabel!
        @IBOutlet weak var productNameLabel: UILabel!
        @IBOutlet weak var priceLabel: UILabel!
        @IBOutlet weak var expireDateLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

       
    }

}
