//
//  BeaconTableViewController.swift
//  IndoorLoc
//
//  Created by Ray Wang on 5/9/18.
//  Copyright © 2018 Korrawat Pruegsanusak. All rights reserved.
//

import UIKit

class BeaconTableViewController: UITableViewController {
    var refreshLoop: Timer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshLoop = Timer(fire: Date(), interval: 0.5, repeats: true, block: { (timer) in
                self.tableView.reloadData()
        })
        
        RunLoop.current.add(self.refreshLoop!, forMode: .defaultRunLoopMode)


        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return globalBeacons.count
    }
    
    func update() {
        self.tableView.reloadData()
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "BeaconTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? BeaconTableViewCell else {
                fatalError("The dequeued cell is not an instance of BeaconTableViewCell.")
        }

        // Configure the cell...
        let beacon = globalBeacons[indexPath.row]
        if beacon == nil {
            return cell
        }
        
        if beacon!.beaconID.beaconNum() == 0 {
            return cell
        }
        
        cell.minorLabel.text = "\(beacon!.beaconID.beaconNum())"
        cell.rssiLabel.text = "\(beacon!.RSSI)"
        
        return cell
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
