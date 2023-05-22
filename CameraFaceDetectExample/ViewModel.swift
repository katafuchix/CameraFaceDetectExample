//
//  FaceDetectionViewModel.swift
//  CameraFaceDetectExample
//
//  Created by cano on 2023/05/22.
//

import Foundation
import AVFoundation
import RxSwift
import RxCocoa
import Vision
 
protocol ViewModelInputs {
    // カメラの出力
    var captureOutputTrigger: PublishSubject<CMSampleBuffer> { get }
}
 
protocol ViewModelOutputs {
    // 顔検出結果画像
    var detectionResultImage: PublishSubject<UIImage?> { get }
}
 
protocol ViewModelType {
    var inputs: ViewModelInputs { get }
    var outputs: ViewModelOutputs { get }
}
 
final class ViewModel: ViewModelType, ViewModelInputs, ViewModelOutputs {
    
    var inputs: ViewModelInputs { return self }
    var outputs: ViewModelOutputs { return self }
 
    // MARK: - input
    var captureOutputTrigger = PublishSubject<CMSampleBuffer>()
 
    // MARK: - output
    var detectionResultImage = PublishSubject<UIImage?>()
 
    // カメラから取得した画像のデータ
    private var sampleBuffer: CMSampleBuffer?
 
    private let disposeBag = DisposeBag()
 
    // 顔検出の円画像を設定
    private var catFaceCgImage: CGImage? = UIImage(named: "circle")?.cgImage
    
    init() {
        self.captureOutputTrigger
            // 画像データを設定
            .map { [unowned self] buffer in self.sampleBuffer = buffer }
            // 顔検出処理
            .flatMapLatest { [unowned self] in return self.detectFace() }
            // 画像の再生成
            .map { [unowned self] in return self.regenerationImage($0) }
            // 検出結果画像にバインド
            .bind(to: self.detectionResultImage)
            .disposed(by: disposeBag)
    }
    
    // 顔検出処理
    private func detectFace() -> Observable<[VNFaceObservation]> {
        return Observable<[VNFaceObservation]>.create({ [weak self] observer in
            if let sampleBuffer = self?.sampleBuffer,
                let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                // 顔検出処理を要求
                let request = VNDetectFaceRectanglesRequest { (request, error) in
                    guard let results = request.results as? [VNFaceObservation] else {
                        // 顔が検出されなかったら空列を流す
                        observer.onNext([])
                        return
                    }
                    // 顔が検出されたら検出結果を流す
                    observer.onNext(results)
                }
                // 顔検出処理を実行
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                try? handler.perform([request])
            }
            return Disposables.create()
        })
    }
    
    // 画像の再生成
    private func regenerationImage(_ faceObservations: [VNFaceObservation]) -> UIImage? {
        guard let sampleBuffer = sampleBuffer else { return nil }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        guard let pixelBufferBaseAddres = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue))
        
        let context = CGContext(
            data: pixelBufferBaseAddres,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        )
        // 検出結果を元に顔の表示位置に対して処理を実行
        faceObservations
            // 表示位置情報（CGRect）に変換（※１）
            .compactMap { $0.boundingBox.converted(to: CGSize(width: width, height: height)) }
            // 検出した顔ごとに画像を描画
            .forEach {
                guard let catFaceCgImage = catFaceCgImage else { return }
                context?.draw(catFaceCgImage, in: $0)
            }
 
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        guard let imageRef = context?.makeImage() else { return nil }
        return UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImage.Orientation.up)
    }
}

extension CGRect {
    func converted(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.minX * size.width,
            y: self.minY * size.height,
            width: self.width * size.width,
            height: self.height * size.height
        )
    }
}
