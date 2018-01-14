//
//  ViewController.swift
//  testWDA
//
//  Created by 李博闻 on 2018/1/10.
//  Copyright © 2018年 艺林. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    let DistPerSecond = 463.0
    let timeInterval: Double = 1  //每隔timeInterval截取一张图像做分析
    var pressTime: Double = 0.7 //按压持续的时间，随着距离变化
    let ip = "http://169.254.74.38:8100/" //wda中分配给iOS终端的IP地址
    let sessionID = "D70BEB2A-D169-4710-AADF-82FCD53E3C82" //wda分配给这次连接的会话ID，每次连接时要更新
    //定时器--定时截图分析
    var timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
    var imageSet: [UIImage] = []
    var guyRect = [[UInt8]]()
    
    
    @IBOutlet var imgView: UIImageView!
    var subview: UIView? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //创建定时任务
        var count = 0
        timer.schedule(deadline: DispatchTime.now(), repeating: timeInterval)
        timer.setEventHandler(handler: {
            if self.subview != nil {
                self.subview?.removeFromSuperview()
                self.subview?.removeFromSuperview()
                self.subview?.removeFromSuperview()
            }
            
            //print(count)
            let path = self.ip + "screenshot"
            let url: URL = NSURL(string: path) as! URL
            
            var string: String = ""
            do {
                string = try NSString(contentsOf: url, encoding: String.Encoding.utf8.rawValue) as String }
            catch let error as NSError {
                print("error in getting data:\(error.description)")
            }
            //print(string)
            let dic: [String: AnyObject] = self.ConvertString2Dictionary(text: string)!
            //print("*******")
            //print(dic)
            let image: UIImage? = self.ConvertString2Image(text: dic["value"] as! String)
            self.imgView.image = image!
            //analyse pictures
            self.imageSet.append(image!)
            count = count + 1
            if count == 3 { //图像缓冲区容量为2
                self.imageSet.remove(at: 0)
                count = count - 1
            }
            if count == 2 { //图像缓冲区内有2幅图像，通过对比这两幅图像是否一样来确定是否可以开始按压
                if self.isEqualImage(imageOne: self.imageSet[0], imageTwo: self.imageSet[1]) {
                    print("Now can press...")
                    //查找下一个块的中点
                    let (x, y) = self.getMidPoint(imageSet: self.imageSet)
                    let screenWidth = UIScreen.main.applicationFrame.size.width
                    let screenHeight = UIScreen.main.applicationFrame.size.height
                    let width_ratio: Double = Double(640) / Double(screenWidth)
                    let height_ratio: Double = Double(1136) / Double(screenHeight)
                    self.subview = UIView.init(frame: CGRect.init(x: Double(x)/width_ratio, y: Double(y)/height_ratio, width: 5, height: 5))
                    //self.subview = UIView.init(frame: CGRect.init(x: 447/width_ratio, y: 416/height_ratio, width: 10, height: 10))
                    self.subview!.backgroundColor = UIColor.black
                    self.view.addSubview(self.subview!)
                    
                    //查找小人的坐标
                    /*let imageGuy = UIImage.init(named: "guy.jpg")
                    let guyWidth = Int(imageGuy!.size.width)
                    let guyHeight = Int(imageGuy!.size.height)
                    for j in 0..<guyHeight {
                        var tmp = [UInt8]()
                        for i in 0..<guyWidth {
                            tmp.append(self.getPixelColor(pos: CGPoint.init(x: i, y: j), image: imageGuy!))
                        }
                        self.guyRect.append(tmp)
                    }*/
                    //print(self.guyRect)
                    var imageRect = [[UInt8]]()
                    /*for j in 0..<Int(self.imageSet[1].size.height) {
                        var tmp = [UInt8]()
                        for i in 0..<Int(self.imageSet[1].size.width) {
                            tmp.append(self.getPixelColor(pos: CGPoint.init(x: i, y: j), image: self.imageSet[1]))
                        }
                        imageRect.append(tmp)
                    }*/
                    let imageData = self.getGrayImage(sourceImage: self.imageSet[1]).cgImage?.dataProvider?.data
                    let iData: UnsafePointer<UInt8> = CFDataGetBytePtr(imageData)
                    for j in 0..<Int(self.imageSet[1].size.height) {
                        var tmp = [UInt8]()
                        for i in 0..<Int(self.imageSet[1].size.width) {
                            tmp.append(iData[j * Int(self.imageSet[1].size.width) + i])
                        }
                        imageRect.append(tmp)
                    }
                    let (gx, gy) = self.getGuyPoint(image: imageRect, width: self.imageSet[1].size.width, height: self.imageSet[1].size.height, midX: x, midY: y)
                    print("guy: (\(gx), \(gy))")
                    self.subview = UIView.init(frame: CGRect.init(x: Double(gx)/width_ratio, y: Double(gy)/height_ratio, width: 5, height: 5))
                    //self.subview = UIView.init(frame: CGRect.init(x: 447/width_ratio, y: 416/height_ratio, width: 10, height: 10))
                    self.subview!.backgroundColor = UIColor.red
                    self.view.addSubview(self.subview!)
                    self.subview = UIView.init(frame: CGRect.init(x: 0, y: Double(400) / height_ratio, width: 640, height: 5))
                    self.subview!.backgroundColor = UIColor.red
                    self.view.addSubview(self.subview!)
                    //计算时间
                    let distance = sqrt(Double((x - gx) * (x - gx) + (y - gy) * (y - gy)))
                    self.pressTime = distance / self.DistPerSecond
                    print("presstime:\(self.pressTime)")
                    
                    //新线程
                    //let newThread = Thread.init(target: self, selector: #selector(self.postToJump), object: nil)
                    //newThread.start()
                    self.postToJump()
                    
                }
                else {
                    /*let screenWidth = UIScreen.main.applicationFrame.size.width
                    let screenHeight = UIScreen.main.applicationFrame.size.height
                    let width_ratio: Double = Double(640) / Double(screenWidth)
                    let height_ratio: Double = Double(1136) / Double(screenHeight)
                    let width = self.imageSet[0].size.width
                    let height = self.imageSet[0].size.height
                    var imageRect1 = [[UInt8]]()
                    let imageData1 = self.getGrayImage(sourceImage: self.imageSet[1]).cgImage?.dataProvider?.data
                    let iData1: UnsafePointer<UInt8> = CFDataGetBytePtr(imageData1)
                    for j in 0..<Int(self.imageSet[1].size.height) {
                        var tmp = [UInt8]()
                        for i in 0..<Int(self.imageSet[1].size.width) {
                            tmp.append(iData1[j * Int(self.imageSet[1].size.width) + i])
                        }
                        imageRect1.append(tmp)
                    }
                    var imageRect0 = [[UInt8]]()
                    let imageData0 = self.getGrayImage(sourceImage: self.imageSet[0]).cgImage?.dataProvider?.data
                    let iData0: UnsafePointer<UInt8> = CFDataGetBytePtr(imageData0)
                    for j in 0..<Int(self.imageSet[0].size.height) {
                        var tmp = [UInt8]()
                        for i in 0..<Int(self.imageSet[0].size.width) {
                            tmp.append(iData0[j * Int(self.imageSet[0].size.width) + i])
                        }
                        imageRect0.append(tmp)
                    }
                    let (mx1, my1) = self.getMidPoint(imageSet: self.imageSet)
                    let (mx0, my0) = self.getMidPoint(imageSet: self.imageSet)
                    let (x1, y1) = self.getGuyPoint(image: imageRect1, width: width, height: height, midX: mx1, midY: my1)
                    let (x0, y0) = self.getGuyPoint(image: imageRect0, width: width, height: height, midX: mx0, midY: my1)
                    if x1 == x0 && y1 == y0 && mx0 == mx1 && my0 == my1 { //小人不动，是周围环境动了
                        print("Now press...")
                        self.subview = UIView.init(frame: CGRect.init(x: Double(x1)/width_ratio, y: Double(y1)/height_ratio, width: 5, height: 5))
                        self.subview!.backgroundColor = UIColor.red
                        self.view.addSubview(self.subview!)
                        self.subview = UIView.init(frame: CGRect.init(x: Double(mx0)/width_ratio, y: Double(my0)/height_ratio, width: 5, height: 5))
                        self.subview!.backgroundColor = UIColor.black
                        self.view.addSubview(self.subview!)
                        //计算时间
                        let distance = sqrt(Double((mx1 - x1) * (mx1 - x1) + (my1 - y1) * (my1 - y1)))
                        self.pressTime = distance / self.DistPerSecond
                        print("presstime:\(self.pressTime)")
                        self.postToJump()
                    }*/
                }
            }
            
        })
        timer.activate()//定时器启动
    }
    //获得小人坐标（下方中间）
    func getMAD(rec1: [[UInt8]], rec2: [[UInt8]], width: CGFloat, height: CGFloat) -> Int32 {
        var mad: Int32 = 0
        for y in 0..<Int(height) {
            for x in 0..<Int(width) {
                mad = mad + abs((Int32(rec1[y][x])-Int32(rec2[y][x])))
            }
        }
        return mad
    }
    func getGuyPoint(image: [[UInt8]], width: CGFloat, height: CGFloat, midX: Int, midY: Int) -> (Int, Int) {
        let bandwidth = Int(width) - 40 - midX
        let search_height = 300

        var bestMAD: Int32 = 1073741823
        var bestPosX = 0
        var bestPosY = 0
        var isFound : Bool = false
        for y in (midY-100)...(midY+search_height) {
            /*var rec2 = [[UInt8]]()
            var left = midX > Int(width / 2) ? midX - bandwidth : midX
            var right = midX > Int(width / 2) ? midX : midX + bandwidth
            for x in left..<right {
                var tmp = [UInt8]()
                for j in 0..<112 {
                    for i in 0..<40 {
                        tmp.append(image[y+j][x+i])
                    }
                    rec2.append(tmp)
                }
                let mad = getMAD(rec1: self.guyRect, rec2: rec2, width: 40, height: 112)
                if mad < bestMAD {
                    bestMAD = mad
                    bestPosX = x
                    bestPosY = y
                }
            }*/
            var left = midX > Int(width / 2) ? 0 : midX
            var right = midX > Int(width / 2) ? midX : Int(width) - 40
            let tmp = image[midX][midY]
            for x in left..<right {
                
                if image[y][x] <= 65 && image[y][x] < tmp && image[y + 112][x] <= 65 && image[y + 112][x] <= tmp{
                    bestPosY = y
                    bestPosX = x
                    isFound = true
                    break
                }
            }
            if isFound {
                break
            }
        }
        return (bestPosX, bestPosY + 125)
    }
    //获得rgb
    func getPixelColor(pos: CGPoint, image: UIImage) -> (UInt8, UInt8, UInt8) {
        var pixelData = image.cgImage?.dataProvider?.data
        var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        var pixelInfo: Int = ((Int(image.size.width) * Int(pos.y)) + Int(pos.x)) * 4
        
        var r = UInt8(data[pixelInfo])
        var g = UInt8(data[pixelInfo+1])
        var b = UInt8(data[pixelInfo+2])
        var a = UInt8(data[pixelInfo+3])
        
        let color = (r, g, b)
        return color
        //return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    //分析图像集，从时域和空域一起得到下一个块的中心点
    func getMidPoint(imageSet: [UIImage]) -> (Int, Int) {
        var point = (0, 0)
        let width = Int(imageSet[0].size.width)
        let height = Int(imageSet[1].size.height)
        let mImageOne = self.getGrayImage(sourceImage: imageSet[0])
        let mImageTwo = self.getGrayImage(sourceImage: imageSet[1])
        //将image2转换为二维矩阵，下面data2为这二维矩阵的指针
        let CGImageTwo = mImageTwo.cgImage
        let pPixelDataTwo = CGImageTwo?.dataProvider?.data
        let pData2: UnsafePointer<UInt8> = CFDataGetBytePtr(pPixelDataTwo)
        //将image1转换为二维矩阵，下面data1为这二维矩阵的指针
        let CGImageOne = mImageOne.cgImage
        let pPixelDataOne = CGImageOne?.dataProvider?.data
        let pData1: UnsafePointer<UInt8> = CFDataGetBytePtr(pPixelDataOne)
        //两幅图像相减得到差值图像
        let num = width*height
        var diffImageArray: [Int16] = []
        var diffRect = [[Int16]]()
        for y in 0..<height {
            var tmp: [Int16] = []
            for x in 1..<width {
                let pos = y * width + x
                let pix = Int16(pData2[pos]) - Int16(pData2[pos-1])
                tmp.append(pix)
            }
            tmp.append(0)
            diffRect.append(tmp)
        }//2D
        //find the toppest point of the new block
        let initial_height = 400 //上方是分数等控件，不需要搜索
        let searchwindow_height = 200
        var findTopPoint: Bool = false
        var topPointX: Int = 0
        var topPointY: Int = 0
        let sigma = 0 //允许误差
        let (er,eg,eb) = self.getPixelColor(pos: CGPoint.init(x: 0, y: initial_height), image: imageSet[1]) //background color
        var diff: [Double] = []
        var count_all: [Int] = []
        for y in initial_height...(initial_height+searchwindow_height) {
            var count = 0
            var difftmp: Int32 = 0
            for x in 0..<width {
                if diffRect[y][x] > sigma {
                    count = count + 1
                    let (r,g,b) = self.getPixelColor(pos: CGPoint.init(x: x, y: y), image: imageSet[1])
                    difftmp = (abs(Int32(r)-Int32(er)) + abs(Int32(g)-Int32(eg)) + abs(Int32(b)-Int32(eb)))
                    if difftmp > 10 {
                        findTopPoint = true
                        topPointX = x
                        topPointY = y
                        break
                    }
                }
            }
            if findTopPoint {
                break
            }
        }
        //find the mid point
        var best_obj_width = 0
        var bestY = 0
        var bestX = 0
        let searchMid_height = 100
        for y in (topPointY+1)...(topPointY+searchMid_height) {
            let range = min(topPointX-1, width-topPointX-1)
            var obj_width = 0
            if diffRect[y][topPointX] <= sigma && diffRect[y][topPointX] >= 0 {
                for i in 0...range {
                    if diffRect[y][topPointX+i] <= sigma && diffRect[y][topPointX+i] >= 0 && diffRect[y][topPointX-i] >= 0 && diffRect[y][topPointX-i] <= sigma {
                        obj_width = obj_width + 1
                    } else {
                        break
                    }
                    /*let (rl,gl,bl) = self.getPixelColor(pos: CGPoint.init(x: y, y: topPointX-i), image: imageSet[1])
                    let (rr,gr,br) = self.getPixelColor(pos: CGPoint.init(x: y, y: topPointX+i), image: imageSet[1])
                    let diffLeft = abs(Int32(rl)-Int32(er)) + abs(Int32(gl)-Int32(eg)) + abs(Int32(bl)-Int32(eb))
                    let diffRight = abs(Int32(rr)-Int32(er)) + abs(Int32(gr)-Int32(eg)) + abs(Int32(br)-Int32(eb))
                    if diffLeft < 3 || diffRight < 3 { //有一边到了边界
                        break
                    } else {
                        obj_width = obj_width + 1
                    }*/
                }
                if obj_width > best_obj_width && obj_width != range {
                    best_obj_width = obj_width
                    bestY = y
                    bestX = topPointX
                }
            }
            else {
                continue
            }
        }
        point = (bestX, bestY)
        print("point:\(point)")
        return point
    }
    
    func RGB2Y (R: CGFloat, G: CGFloat, B: CGFloat) -> UInt8
    {
        let Y = UInt8(0.299 * Double(R) + 0.587 * Double(R) + 0.114 * Double(B))
        return Y
    }
    
    func isEqualImage(imageOne: UIImage, imageTwo: UIImage) -> Bool {
        var equalResult = false
        let mImageOne = self.getGrayImage(sourceImage: imageOne)
        let mImageTwo = self.getGrayImage(sourceImage: imageTwo)
        let diff = self.getDifferentValueCountWithString(str1: self.pHashValueWithImage(image: mImageOne), str2: self.pHashValueWithImage(image: mImageTwo))
        print("hashDiff:\(diff)")
        if diff > 30 {
            equalResult = false
        } else {
            equalResult = true
        }
        return equalResult
    }
    
    func getDifferentValueCountWithString(str1: NSString, str2: NSString) -> NSInteger {
        var diff: NSInteger = 0
        let s1 = str1.utf8String!
        let s2 = str2.utf8String!
        for i in 0..<str1.length {
            if s1[i] != s2[i] {
                diff += 1
            }
        }
        return diff
    }
    
    func pHashValueWithImage(image: UIImage) -> NSString {
        let pHashString = NSMutableString()
        let imageRef = image.cgImage!
        let width = imageRef.width
        let height = imageRef.height
        let pixelData = imageRef.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        var sum: Int = 0
        for i in 0..<width * height {
            if data[i] != 0 {
                sum = sum + Int(data[i])
            }
        }
        let avr = sum / (width * height)
        for i in 0..<width * height {
            if Int(data[i]) >= avr {
                pHashString.append("1")
            } else {
                pHashString.append("0")
            }
        }
        return pHashString
    }
    
    func getGrayImage(sourceImage: UIImage) -> UIImage {
        let imageRef: CGImage = sourceImage.cgImage!
        let width: Int = imageRef.width
        let height: Int = imageRef.height
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let context: CGContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
        
        let rect: CGRect = CGRect.init(x: 0, y: 0, width: width, height: height)
        context.draw(imageRef, in: rect)
        
        let outPutImage: CGImage = context.makeImage()!
        
        let newImage: UIImage = UIImage.init(cgImage: outPutImage)
        
        return newImage
    }
    
    @objc func postToJump() {
        let urlPath = self.ip + "session/" + self.sessionID + "/wda/touchAndHold"
        //print("path: \(urlPath)")
        //let parameters = "-d \"{\"duration\": \"\(self.pressTime)\"}\""
        //let parameters = "-d \"{\"duration\": 10.0}\""
        let parameters: NSMutableDictionary = NSMutableDictionary.init()
        parameters["duration"] = self.pressTime
        //print("param: \(parameters)")
        post(url: urlPath, parameters: parameters)
    }
    
    func post(url: String, parameters: NSMutableDictionary) {
        //创建会话对象
        let session = URLSession.shared
        let serUrl = URL(string: url)
        var request = URLRequest(url: serUrl!)
        //设置访问方式为post
        request.httpMethod = "POST"
        //设置post内容
        //request.httpBody = parameters.data(using: String.Encoding.utf8)
        var JsonData: Data? = nil
        do {
            JsonData = try JSONSerialization.data(withJSONObject: parameters, options: JSONSerialization.WritingOptions.prettyPrinted)}
        catch let errorPost as NSError {
            if errorPost != nil {
                print("instruction transmit error:\(errorPost.description)")
            }
        }
        request.httpBody = JsonData
        //开始访问
        let dataTask: URLSessionDataTask = session.dataTask(with: request, completionHandler:{(data, response, error) -> Void in
            if error != nil {
                //访问出错
                print("POST error:\(error.debugDescription)")
            }
            else{
                let str = String.init(data: data!, encoding: String.Encoding.utf8)
                //print("POST success:\(str!)")
            }
        })
        dataTask.resume()
    }

    func ConvertString2Dictionary(text: String) -> [String: AnyObject]? {
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.init(rawValue: 0)) as! [String: AnyObject] }
            catch let error as NSError {
                print("transvert error:\(error.description)")
            }
        }
        return nil
    }
    
    func ConvertString2Image(text: String) -> UIImage? {
        //if let data = text.data(using: String.Encoding.utf8) {
        if let data = NSData.init(base64Encoded: text, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) {
            let image: UIImage? = UIImage.init(data: data as Data)
            return image
        }
        return nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

