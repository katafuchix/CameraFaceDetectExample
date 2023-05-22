//
//  ViewController.swift
//  CameraFaceDetectExample
//
//  Created by cano on 2023/05/22.
//

import UIKit
import AVFoundation
import RxSwift
import RxCocoa
import NSObject_Rx

class ViewController: UIViewController {

    @IBOutlet weak var detectionResultImageView: UIImageView!
    
    private var avCaptureSession = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
 
    // カメラの出力結果を流すためのStream
    private let capturedOutputStream = PublishSubject<CMSampleBuffer>()
    
    private var viewModel = ViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.bind()
        self.setupViews()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.avCaptureSession.stopRunning()
    }

    func bind() {
        // カメラ入出力から画像認証へ
        self.capturedOutputStream
            .bind(to: self.viewModel.inputs.captureOutputTrigger)
                .disposed(by: rx.disposeBag)
     
        // 顔認証画像出力
        self.viewModel.outputs.detectionResultImage
                .bind(to: detectionResultImageView.rx.image)
                .disposed(by: rx.disposeBag)
    }
 
    private func setupViews() {
        self.avCaptureSession.sessionPreset = .photo
 
        // AVCaptureSession#addInput
        self.videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        guard let videoDevice = videoDevice else { return }
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        self.avCaptureSession.addInput(deviceInput)
 
        // AVCaptureSession#addOutput
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.setSampleBufferDelegate(self, queue: .global())
        self.avCaptureSession.addOutput(videoDataOutput)
 
        // バックグラウンド実行
        DispatchQueue.global(qos: .userInitiated).async {
            self.avCaptureSession.startRunning()
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
 
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // カメラの出力
        capturedOutputStream.onNext(sampleBuffer)
        connection.videoOrientation = .portrait
    }
}
