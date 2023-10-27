//
//  ViewController.swift
//  CardScanner
//
//  Created by Vidyarani Balakrishna on 26/10/2023.
//

import UIKit
import Vision
import VisionKit

class ViewController: UIViewController, VNDocumentCameraViewControllerDelegate {

    @IBOutlet weak var cardInfo: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cardInfo.text = "Card info not available."
    }


    @IBAction func scanCard(_ sender: Any) {
        let documentController = VNDocumentCameraViewController()
        documentController.delegate = self
        present(documentController, animated: true)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        print("Found \(scan.pageCount)")
        let image = scan.imageOfPage(at: 0)
        let cn = validateImage(image: image)
        controller.dismiss(animated: true)
        self.cardInfo.text = cn != nil ? cn : "Card info not available."
    }
    
    func validateImage(image: UIImage?) -> String? {
        guard let cgImage = image?.cgImage else { return nil }
        
        var recognizedText = [String]()
        var textRecognitionRequest = VNRecognizeTextRequest()
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = false
        textRecognitionRequest = VNRecognizeTextRequest() { (request, error) in
            guard let results = request.results,
                  !results.isEmpty,
                  let requestResults = request.results as? [VNRecognizedTextObservation]
            else { return }
            recognizedText = requestResults.flatMap({ $0.topCandidates(100).map({ $0.string }) })
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([textRecognitionRequest])
            print("info: \(recognizedText)")
            for item in recognizedText {
                let trimmed = item.replacingOccurrences(of: " ", with: "")
                if trimmed.count >= 15 &&
                    trimmed.count <= 16 &&
                    isOnlyNumbers(trimmed) {
                    return trimmed
                }
            }
        } catch {
            print(error)
        }
        return nil
    }
    
    private func isOnlyNumbers(_ cardNumber: String) -> Bool {
        return !cardNumber.isEmpty && cardNumber.range(of: "[^0-9]", options: .regularExpression) == nil
    }
}

