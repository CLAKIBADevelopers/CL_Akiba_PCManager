//
//  PCViewCell.swift
//  PCManagement
//
//  Created by KentaroAbe on 2017/12/20.
//  Copyright © 2017年 KentaroAbe. All rights reserved.
//

import UIKit

class PCViewCell: UITableViewCell {
    
    
    @IBOutlet var PCCode: UILabel!
    @IBOutlet var BelongTo: UILabel!
    @IBOutlet var rentTo: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
