//
//  CameraFilterViewController.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/06.
//

import UIKit
import Firebase

final class CameraFilterTableViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var filterDataManager = FilterDataManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //for custom section
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
        
        //extension for tableView
        tableView.delegate = self
        tableView.dataSource = self
                
        setup()
    }
       
    private func setup() {
        tableView.rowHeight = 120
    
        navigationController?.navigationBar.topItem?.title = ""
        
        loadItems()
    }
    
    private func loadItems() {
        if filterDataManager.checkIsDiscreteArrayEmpty() {
            filterDataManager.makeDiscreteFilterData()
        }
    }
    

    // Dispose of any resources that can be recreated.
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    deinit {
        print("TableVC released from memory")
    }
    
    
}

//MARK: - Delegate for TableView

extension CameraFilterTableViewController: UITableViewDataSource {
    
    //section 개수
    func numberOfSections(in tableView: UITableView) -> Int {
        return filterDataManager.getSections().count
    }
    
    //각 section의 title 설정
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return filterDataManager.getSections()[section]
        
    }
    
    //각 section에 몇개의 row 포함시킬지 --> section 구분해서 넣기
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return filterDataManager.getOldFilmData().count
        } else {
            return filterDataManager.getThemeFilterData().count
        }
    }
    
    //cell 생성
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomTableViewCell", for: indexPath) as! CustomTableViewCell
        
        if indexPath.section == 0 {
            let filter = filterDataManager.getOldFilmData()[indexPath.row]
            cell.filterImageView.image = filter.coverImage
            cell.filterLabel.text = filter.nameLabel
        } else {
            let filter = filterDataManager.getThemeFilterData()[indexPath.row]
            cell.filterImageView.image = filter.coverImage
            cell.filterLabel.text = filter.nameLabel
        }
    
        return cell
    }
    
}

extension CameraFilterTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "toCameraFilterVC", sender: indexPath)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toCameraFilterVC" {
            let cameraFilterVC = segue.destination as! CameraFilterViewController
            
            let indexPath = sender as! IndexPath
            if indexPath.section == 0 {
                cameraFilterVC.filterData = filterDataManager.getOldFilmData()[indexPath.row]
            } else {
                cameraFilterVC.filterData = filterDataManager.getThemeFilterData()[indexPath.row]
            }
           
        }
        
        let event = "tableCell"
        let parameters = [
            "file": #file,
            "function": #function
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
        
    }
    
    //header 역할의 section custom하기
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")
        header?.textLabel?.textColor = UIColor(named: "textColor")
        return header
    }
    
    //header 간격 설정
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30.0
    }
    
}
