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

class PCData:Object{
    @objc dynamic var IDinCourse = 0
    @objc dynamic var vendor = ""
    @objc dynamic var pcCode = ""
    @objc dynamic var isOut = false
    @objc dynamic var rentPCto = ""
    @objc dynamic var belonging = ""
    @objc dynamic var comment = ""
}

class ViewController: UIViewController,AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet var toolBar: UIToolbar!
    
    @IBOutlet var isOn: UISwitch!
    
    var realm:Realm!
    
    var isLogined = false
    
    var user:SyncUser?
    
    private let session = AVCaptureSession()
    
    func setupRealm() {
        // ... existing function ...
        let realmAuthURL = URL(string:"http://10.200.3.1:9080")!
        let realmURL = URL(string:"realm://10.200.3.1:9080/~/realm")!
        print(realmURL)
        var isDone = true
        
        let credentials = SyncCredentials.usernamePassword(username: "clk_system_user@localhost", password: "Clark_Sys", register: false)
        SyncUser.logIn(with: credentials, server: realmAuthURL) { user, error in
            DispatchQueue.main.async {
                if let user = user {
                    Realm.Configuration.defaultConfiguration = Realm.Configuration(
                        syncConfiguration: SyncConfiguration(user: user,realmURL: realmURL),
                        objectTypes: [PCData.self]
                        
                    )
                    print("データベースへの接続を確立しました")
                    self.realm = try! Realm(configuration: Realm.Configuration.defaultConfiguration)
                    //print(self.realm.objects(PCData.self))
                    
                    if self.realm.objects(PCData.self).count == 0{
                        print("データの書き込みを行います")
                        let data = PCData()
                        data.isOut = false
                        data.pcCode = "***METADATA***"
                        data.rentPCto = ""
                        data.IDinCourse = 999999999999
                        data.belonging = "Master"
                        try! self.realm.write {
                            self.realm.add(data)
                        }
                    }else{
                        print(self.realm.objects(PCData.self))
                    }
                    isDone = false
                }
                
                
            }
        }
        let runLoop = RunLoop.current
        while isDone &&
            runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                // 0.1秒毎の処理なので、処理が止まらない
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        //self.present(loginController, animated: true, completion: nil)
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
                        self.session.startRunning()
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
            do { //読み込み時に音を出す（暫定でApplePayの決済音、権利問題があるので置き換えを推奨）
                
                let filePath = Bundle.main.path(forResource: "pay", ofType: "m4a") //pay.m4aのパスを取得
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
            if self.isOn.isOn == true{
                self.register(code: metadata.stringValue!, isIn: true)
            }else{
                self.dataSet(code: metadata.stringValue!, isIn: false, toPC: "")
            }
        }
    }
    ///isInは貸出中かどうか（isMustInの略と憶えてね）
    
    func register(code:String,isIn:Bool){
        var toPC = ""
        let alert = UIAlertController(title: "貸出先選択", message: "", preferredStyle: .alert)
        print("貸し出し処理をします")
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
        
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func dataSet(code:String,isIn:Bool,toPC:String){
        print(code)
        print(toPC)
        self.session.startRunning()
        
        let currentData = self.realm.objects(PCData.self).filter("pcCode == %@",code)
        try! self.realm.write {
            currentData.first!.isOut = isIn
            currentData.first!.rentPCto = toPC
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.setupRealm()
    }
    
    override func viewDidAppear(_ animated: Bool) {
    
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    


}

class PCTableViewController:UIViewController,UITableViewDelegate,UITableViewDataSource{
    let db = try! Realm(configuration: Realm.Configuration.defaultConfiguration)
    var isOuttingPC = true
    
    @IBOutlet var table: UITableView!
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let data = db.objects(PCData.self).filter("isOut == %@",isOuttingPC).sorted(byKeyPath: "pcCode", ascending: true)
        print(data)
        return data.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PCView") as! PCViewCell
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
