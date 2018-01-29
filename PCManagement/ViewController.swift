//
//  ViewController.swift
//  PCManagement
//
//  Created by KentaroAbe on 2017/12/18.
//  Copyright © 2017年 KentaroAbe. All rights reserved.
//

import UIKit
import Realm
import RealmSwift
import RealmLoginKit
import AVFoundation
import SwiftyJSON

class PCData:Object{
    @objc dynamic var IDinCourse = 0
    @objc dynamic var vendor = ""
    @objc dynamic var pcCode = ""
    @objc dynamic var isOut = false
    @objc dynamic var rentPCto = ""
    @objc dynamic var belonging = ""
    @objc dynamic var comment = ""
}

class connectData:Object{
    @objc dynamic var SettingName = ""
    @objc dynamic var IPAddress = ""
    @objc dynamic var UserName = ""
    @objc dynamic var Password = ""
}

class permissionData:Object{
    @objc dynamic var permissionName = "" //権限名
    @objc dynamic var permissionLevel = 0 //権限レベル
    @objc dynamic var isPermissionLimited = false //sudoにおいて、昇格先の権限に制限が加えられているか
    @objc dynamic var isUniquePermission = false //ユニーク権限か
    @objc dynamic var isCanSeeAccessLogs = false //アクセスログの閲覧が可能か（root及びmoderatorのみtrue）
    @objc dynamic var CanEditLevel = 0 //データの書き換え可能レベル
    @objc dynamic var isCanEditUser = false //ユーザーの変更が可能か
    @objc dynamic var isCanSudo = false //sudo権限の行使が可能か
    @objc dynamic var sudoLevel = 0 //sudoレベル（moderator->root・・・0 master->moderator・・・1）
    @objc dynamic var isCanAddNewAccount = false //新規ユーザーの作成が可能か
    @objc dynamic var CanAddUserLevel = 0 //作成可能なユーザーの最大権限レベル
}

class ViewController: UIViewController,AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet var toolBar: UIToolbar!
    
    @IBOutlet var isOn: UISwitch!
    
    var realm:Realm!
    
    var isLogined = false
    
    var user:SyncUser?
    
    private let session = AVCaptureSession()
    
    let alert = UIAlertController(title: "サーバーに接続しています...", message: "", preferredStyle: .alert)
    
    func setupRealm() {
        let db = try! Realm()
        let data = db.objects(connectData.self)
        let connect = data.first!
        self.present(self.alert, animated: true, completion: nil)
        
        if connect.IPAddress != "localMyDevice"{
            
            let realmAuthURL = URL(string:"http://\(connect.IPAddress)")!
            let realmURL = URL(string:"realm://\(connect.IPAddress)/realm")!
            print(realmURL)
            var isDone = true
            
            let credentials = SyncCredentials.usernamePassword(username: connect.UserName, password: connect.Password, register: false)
            SyncUser.logIn(with: credentials, server: realmAuthURL) { user, error in
                DispatchQueue.main.async {
                    if let user = user {
                        Realm.Configuration.defaultConfiguration = Realm.Configuration(
                            syncConfiguration: SyncConfiguration(user: user,realmURL: realmURL),
                            objectTypes: [PCData.self]
                            
                        )
                        print("データベースへの接続を確立しました")
                        self.realm = try! Realm(configuration: Realm.Configuration.defaultConfiguration)
                        
                        if self.realm.objects(PCData.self).count == 0{ //DBサーバーにデータが存在しない場合はダミーオブジェクトを作成（通常データに影響を及ぼさないように）
                            print("データの書き込みを行います")
                            let data = PCData()
                            data.isOut = false
                            data.pcCode = "***METADATA***"
                            data.rentPCto = ""
                            data.IDinCourse = 9999999
                            data.belonging = "Master"
                            try! self.realm.write {
                                self.realm.add(data)
                            }
                        }else{
                            print(self.realm.objects(PCData.self))
                        }
                        isDone = false
                    }
                    if error != nil{ //何らかの理由で接続できなかった場合はエラーとしてアプリを終了させる
                        print(error)
                        self.alert.dismiss(animated: false, completion: nil)
                        let errorAlert = UIAlertController(title: "データベース接続エラー", message: "アプリを終了して再度試してみてください\n\(error!)", preferredStyle: .alert)
                        let action = UIAlertAction(title: "OK", style: .default, handler: {action in
                            exit(0)
                        })
                        errorAlert.addAction(action)
                        self.present(errorAlert, animated: true, completion: nil)
                        //isDone = false
                        //self.realm = try! Realm()
                    }
                    
                    
                }
            }
            let runLoop = RunLoop.current
            while isDone &&
                runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                    // 0.1秒毎の処理なので、処理が止まらない
            }
            alert.dismiss(animated: true, completion: nil)
        }else{
            let ap = UIApplication.shared.delegate as! AppDelegate
            ap.isLocal = true
            self.realm = try! Realm()
        }
    }
    
    
    @IBAction func PCView(_ sender: Any) {
        self.session.stopRunning()
    }
    
    func startSession(){
        self.session.startRunning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // カメラやマイクのデバイスそのものを管理するオブジェクトを生成（ここではワイドアングルカメラ・ビデオ・背面カメラを指定）
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                mediaType: .video,
                                                                position: .back)
        
        // ワイドアングルカメラ・ビデオ・背面カメラに該当するデバイスを取得
        let devices = discoverySession.devices
        
        //　該当するデバイスのうち最初に取得したものを利用する
        if let backCamera = devices.first {
            do {
                // QRコードの読み取りに背面カメラの映像を利用するための設定
                let deviceInput = try AVCaptureDeviceInput(device: backCamera)
                
                if self.session.canAddInput(deviceInput) {
                    self.session.addInput(deviceInput)
                    
                    // 背面カメラの映像からQRコードを検出するための設定
                    let metadataOutput = AVCaptureMetadataOutput()
                    
                    if self.session.canAddOutput(metadataOutput) {
                        self.session.addOutput(metadataOutput)
                        
                        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                        metadataOutput.metadataObjectTypes = [.qr]
                        
                        // 背面カメラの映像を画面に表示するためのレイヤーを生成
                        let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                        previewLayer.frame = self.view.bounds
                        previewLayer.videoGravity = .resizeAspectFill
                        self.view.layer.addSublayer(previewLayer)
                        //self.view.addSubview(toolBar)
                        
                        // 読み取り開始
                        
                    }
                }
            } catch {
                print("Error occured while creating video device input: \(error)")
            }
        }
        self.view.addSubview(toolBar)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for metadata in metadataObjects as! [AVMetadataMachineReadableCodeObject] {
            var audioPlayer : AVAudioPlayer! = nil
            do {
                
                let filePath = Bundle.main.path(forResource: "pay", ofType: "mp3") //pay.mp3のパスを取得
                print(filePath)
                let audioPath = URL(fileURLWithPath: filePath!)
                audioPlayer = try AVAudioPlayer(contentsOf: audioPath as URL)
                audioPlayer.prepareToPlay()
                
            } catch {
                print("Error")
            }
            
            audioPlayer.play() //再生
            // QRコードのデータかどうかの確認
            if metadata.type != .qr { continue }
            
            // QRコードの内容が空かどうかの確認
            if metadata.stringValue == nil { continue }
            
            self.session.stopRunning() //QRコードの読み取りセッションを一時停止
            print(metadata.stringValue)
            if self.isOn.isOn == true{ //トグルがオンになっている場合は貸出モード
                self.register(code: metadata.stringValue!, isIn: true)
            }else{ //トグルがオフの場合は返却モード（貸出先を空文字で送信）
                self.dataSet(code: metadata.stringValue!, isIn: false, toPC: "")
            }
        }
    }
    ///isInは貸出中かどうか（isMustInの略と憶えてね）
    
    func register(code:String,isIn:Bool){
        var toPC = ""
        let alert = UIAlertController(title: "貸出先選択", message: "", preferredStyle: .alert)
        print("貸し出し処理をします")
        
        ///***以下削除済み処理***///
        /*
        let game8F = UIAlertAction(title: "8Fゲーム専攻", style: .default, handler: { action in
            self.dataSet(code: code, isIn: isIn, toPC: "8Fゲーム専攻")
        })
        let game2F = UIAlertAction(title: "2Fゲーム専攻", style: .default, handler: { action in
            self.dataSet(code: code, isIn: isIn, toPC: "2Fゲーム専攻")
        })
        let comic = UIAlertAction(title: "コミック専攻", style: .default, handler: { action in
            self.dataSet(code: code, isIn: isIn, toPC: "コミック専攻")
        })
        let voice = UIAlertAction(title: "声優専攻", style: .default, handler: { action in
            self.dataSet(code: code, isIn: isIn, toPC: "声優専攻")
        })
        let other = UIAlertAction(title: "その他", style: .default, handler: { action in
            let message = UIAlertController(title: "貸出先", message: "貸出先名を入力してください", preferredStyle:.alert)
            let box = UITextField()
            let button = UIAlertAction(title: "OK", style: .default, handler:  {action in
                self.dataSet(code: code, isIn: isIn, toPC: message.textFields!.first!.text!)
            })
            message.addTextField(configurationHandler: nil)
            message.addAction(button)
            self.present(message, animated: true, completion: nil)
        })
        let cancel = UIAlertAction(title: "キャンセル", style: .cancel, handler:{action in
            self.session.startRunning()
        })
        alert.addAction(game8F)
        alert.addAction(game2F)
        alert.addAction(comic)
        alert.addAction(voice)
        alert.addAction(other)
        alert.addAction(cancel)
        */
        let db = try! Realm()
        let metaData = db.objects(connectData.self)
        if metaData.first!.SettingName != "LocalEnvironment"{
            let json = JsonGet(fileName: "CompanyCode")
            for i in 1...json[metaData.first!.SettingName]["toSubscription"].count{
                let action = UIAlertAction(title: String(describing:json[metaData.first!.SettingName]["toSubscription"][String(describing:i)]), style: .default, handler: {action in
                    self.dataSet(code: code, isIn: isIn, toPC: String(describing:json[metaData.first!.SettingName]["toSubscription"][String(describing:i)]))
                })
                alert.addAction(action)
            }
            let other = UIAlertAction(title: "その他", style: .default, handler: { action in
                let message = UIAlertController(title: "貸出先", message: "貸出先名を入力してください", preferredStyle:.alert)
                let button = UIAlertAction(title: "OK", style: .default, handler:  {action in
                    self.dataSet(code: code, isIn: isIn, toPC: message.textFields!.first!.text!)
                })
                message.addTextField(configurationHandler: nil)
                message.addAction(button)
                self.present(message, animated: true, completion: nil)
            })
            alert.addAction(other)
            let cancel = UIAlertAction(title: "キャンセル", style: .cancel, handler:{action in
                self.session.startRunning()
            })
            alert.addAction(cancel)
            self.present(alert, animated: true, completion: nil)
            
        }else{
            let message = UIAlertController(title: "貸出先", message: "貸出先を入力してください", preferredStyle:.alert)
            //let box = UITextField()
            let button = UIAlertAction(title: "OK", style: .default, handler:  {action in
                self.dataSet(code: code, isIn: isIn, toPC: message.textFields!.first!.text!)
            })
            message.addTextField(configurationHandler: nil)
            message.addAction(button)
            let cancel = UIAlertAction(title: "キャンセル", style: .cancel, handler:{action in
                self.session.startRunning()
            })
            message.addAction(cancel)
            self.present(message, animated: true, completion: nil)
        }
    }
    
    func JsonGet(fileName :String) -> JSON {
        let path = Bundle.main.path(forResource: fileName, ofType: "json")
        print(path)
        
        do{
            let jsonStr = try String(contentsOfFile: path!)
            //print(jsonStr)
            
            let json = JSON.parse(jsonStr)
            
            return json
        } catch {
            return nil
        }
        
    }
    
    func dataSet(code:String,isIn:Bool,toPC:String){
        print(code)
        print(toPC)
        self.session.startRunning()
        var db:Realm!
        let ap = UIApplication.shared.delegate as! AppDelegate
        if ap.isLocal == false{
            db = try! Realm(configuration: Realm.Configuration.defaultConfiguration)
        }else{
            db = try! Realm()
        }
        
        let currentData = db.objects(PCData.self).filter("pcCode == %@",code) //DBに同一のPCコードのデータを問い合わせ
        print(currentData.count)
        if currentData.count == 0{
            let data = PCData()
            data.isOut = isIn
            data.IDinCourse = 0
            data.pcCode = code
            data.rentPCto = toPC
            data.belonging = "hogehoge"
            
            try! self.realm.write {
                self.realm.add(data)
            }
        }else{
            try! self.realm.write { //最初のデータを書き換えてDBに登録（サーバーへの同期はRealm側の処理）
                currentData.first!.isOut = isIn
                currentData.first!.rentPCto = toPC
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
    }
    
    override func viewDidAppear(_ animated: Bool) { //表示完了後にRealmへの接続確立と読み取りセッションの開始（Realmサーバーに接続できるまでセッションは開始しない）
        let ap:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        if ap.isComplete == false{
            self.setupRealm()
            ap.isComplete = true
        }
        self.startSession()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    


}

class PCTableViewController:UIViewController,UITableViewDelegate,UITableViewDataSource{
    
    
    @IBAction func Close(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        
    }
    var db:Realm!
    let ap = UIApplication.shared.delegate as! AppDelegate
    
    var isOuttingPC = true
    
    @IBOutlet var table: UITableView!
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.ap.isLocal == false{
            db = try! Realm(configuration: Realm.Configuration.defaultConfiguration)
        }else{
            db = try! Realm()
        }
        let data = db.objects(PCData.self).filter("isOut == %@",isOuttingPC).sorted(byKeyPath: "pcCode", ascending: true)
        print(data)
        return data.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PCView") as! PCViewCell
        if self.ap.isLocal == false{
            db = try! Realm(configuration: Realm.Configuration.defaultConfiguration)
        }else{
            db = try! Realm()
        }
        let data = db.objects(PCData.self).filter("isOut == %@",isOuttingPC).sorted(byKeyPath: "pcCode", ascending: true)
        cell.PCCode.text = data[indexPath.row].pcCode
        cell.rentTo.text = data[indexPath.row].rentPCto
        cell.BelongTo.text = data[indexPath.row].belonging
        
        return cell
    }
    
    override func viewDidLoad(){
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        
        table.rowHeight = 70.0
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    
    
}

class FirstSettingsController:UIViewController{
    
    @IBOutlet weak var CompanyCode: UITextField!
    
    @IBOutlet weak var UserName: UITextField!
    
    @IBOutlet weak var Password: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        CompanyCode.endEditing(true)
        UserName.endEditing(true)
        Password.endEditing(true)
    }
    
    @IBAction func Register(_ sender: Any) {
        
        if CompanyCode.text != nil && UserName.text != nil && Password.text != nil{
            let json = JsonGet(fileName: "CompanyCode")
            let db = try! Realm()
            let data = connectData()
            var URL = ""
            if json[CompanyCode.text!] != nil{
                URL = String(describing:json[CompanyCode.text!]["URL"])
                data.SettingName = CompanyCode.text!
            }else{
                URL = CompanyCode.text!
                data.SettingName = "LocalEnvironment"
            }
            data.IPAddress = URL
            data.UserName = UserName.text!
            data.Password = Password.text!
            
            try! db.write {
                db.add(data)
            }
            
            print(db.objects(connectData.self))
            //setupRealm()
            
            let alert = UIAlertController(title: "設定が完了しました", message: "アプリを再起動してください", preferredStyle: .alert)
            let OKButton = UIAlertAction(title: "OK", style: .default, handler: {action in
                exit(0)
            })
            alert.addAction(OKButton)
            self.present(alert, animated: true, completion: nil)
        }else{
            if UserName.text == "localhost" && Password.text != nil{
                let db = try! Realm()
                let data = connectData()
                data.IPAddress = "localMyDevice"
                data.UserName = UserName.text!
                data.Password = Password.text!
                try! db.write {
                    db.add(data)
                }
                let alert = UIAlertController(title: "設定が完了しました", message: "サーバーに接続しての使用はできません\nアプリを再起動してください", preferredStyle: .alert)
                let OKButton = UIAlertAction(title: "OK", style: .default, handler: {action in
                    exit(0)
                })
                alert.addAction(OKButton)
                self.present(alert, animated: true, completion: nil)
            }else{
                let errorAlert = UIAlertController(title: "エラー", message: "すべての項目を入力してください", preferredStyle: .alert)
                let OKButton = UIAlertAction(title: "OK", style: .default, handler: {action in
                    
                })
                errorAlert.addAction(OKButton)
                self.present(errorAlert, animated: true, completion: nil)
            }
        }
    }
    
    let alert = UIAlertController(title: "サーバーに接続しています...", message: "", preferredStyle: .alert)
    
    func setupRealm() {
        let db = try! Realm()
        let data = db.objects(connectData.self)
        let connect = data.first!
        self.present(self.alert, animated: true, completion: nil)
        
        let realmAuthURL = URL(string:"http://\(connect.IPAddress)")!
        let realmURL = URL(string:"realm://\(connect.IPAddress)/realm")!
        print(realmURL)
        var isDone = true
        
        let credentials = SyncCredentials.usernamePassword(username: connect.UserName, password: connect.Password, register: false)
        SyncUser.logIn(with: credentials, server: realmAuthURL) { user, error in
            DispatchQueue.main.async {
                if let user = user {
                    Realm.Configuration.defaultConfiguration = Realm.Configuration(
                        syncConfiguration: SyncConfiguration(user: user,realmURL: realmURL),
                        objectTypes: [PCData.self]
                        
                    )
                    print("データベースへの接続を確立しました")

                    isDone = false
                }
                if error != nil{ //何らかの理由で接続できなかった場合はデータの同期ができず本末転倒なので終了させる
                    print(error)
                    self.alert.dismiss(animated: false, completion: nil)
                    let errorAlert = UIAlertController(title: "データベース接続エラー", message: "アプリを終了して再度試してみてください\n\(error!)", preferredStyle: .alert)
                    let action = UIAlertAction(title: "OK", style: .default, handler: {action in
                        exit(0)
                    })
                    errorAlert.addAction(action)
                    self.present(errorAlert, animated: true, completion: nil)
                }
                
                
            }
        }
        let runLoop = RunLoop.current
        while isDone &&
            runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                // 0.1秒毎の処理なので、処理が止まらない
        }
        alert.dismiss(animated: true, completion: nil)
    }
    
    func JsonGet(fileName :String) -> JSON {
        let path = Bundle.main.path(forResource: fileName, ofType: "json")
        print(path)
        
        do{
            let jsonStr = try String(contentsOfFile: path!)
            //print(jsonStr)
            
            let json = JSON.parse(jsonStr)
            
            return json
        } catch {
            return nil
        }
        
    }
}
