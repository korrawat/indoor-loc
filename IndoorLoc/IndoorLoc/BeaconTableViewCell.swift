//
//  BeaconTableViewCell.swift
//  IndoorLoc
//
//  Created by Ray Wang on 5/9/18.
//  Copyright © 2018 Korrawat Pruegsanusak. All rights reserved.
//

import UIKit

class BeaconTableViewCell: UITableViewCell {
    //MARK: Properties

    @IBOutlet weak var minorLabel: UILabel!
    @IBOutlet weak var rssiLabel: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
