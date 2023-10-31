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
    
    var barcodeRecognitionRequest = VNDetectBarcodesRequest()
    lazy var detectBarcodeRequest = VNDetectBarcodesRequest { request, error in
      guard error == nil else {
        self.cardInfo.text = error?.localizedDescription ?? "error"
        return
      }
        self.processBarcodes(results: request.results)
    }
    
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
      validateCardImage(image: image)
//        validateBarcode(image: image)
        controller.dismiss(animated: true)
    }
    
    func validateCardImage(image: UIImage?) {
        guard let cgImage = image?.cgImage else { return }
        
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
                    self.cardInfo.text = trimmed
                    return
                }
            }
        } catch {
            print(error)
        }
        return
    }
    
    private func isOnlyNumbers(_ cardNumber: String) -> Bool {
        return !cardNumber.isEmpty && cardNumber.range(of: "[^0-9]", options: .regularExpression) == nil
    }
    
    func validateBarcode(image: UIImage?) {
        guard let cgImage = image?.cgImage else { return }
                
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([detectBarcodeRequest])
        } catch {
            print(error)
        }
    }
    
    func processBarcodes(results: [Any]?) {
        guard let results = results else {
              return print("No results found.")
        }
        print("Number of results found: \(results.count)")
        
        for result in results {
          if let barcode = result as? VNBarcodeObservation {
            
            if let payload = barcode.payloadStringValue {
                let data = Barcode(payload)
                do {
                    let decoded = try data.decode(data)
                    self.cardInfo.text = decoded
                } catch let err as NSError {
                    print("Error decoding: \(err)")
                }
                print("Payload: \(payload)")
            }
            
            // Print barcode-values
            print("Symbology: \(barcode.symbology.rawValue)")
            
            if let desc = barcode.barcodeDescriptor as? CIQRCodeDescriptor {
              let content = String(data: desc.errorCorrectedPayload, encoding: .utf8)
              
              // FIXME: This currently returns nil. I did not find any docs on how to encode the data properly so far.
              print("Payload: \(String(describing: content))")
              print("Error-Correction-Level: \(desc.errorCorrectionLevel)")
              print("Symbol-Version: \(desc.symbolVersion)")
            }
          }
        }
    }
}

public struct Barcode
{
    let data: String!

    init(_ string: String!)
    {
        self.data = string
    }
    
    func decode(_ barcode: Barcode!) throws -> String?
    {
        print("Decoding barcode: Began for length \(barcode.data.count)")

        // Min length?
        guard barcode.data.count >= 58
        else
        {
            print("Decoding barcode: Invalid length (\(barcode.data.count)).")
            return nil
        }

        var newBarcode = barcode.data!

        
        let formatCode: String? = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 1))
        let validFormatCodes = CharacterSet(charactersIn: "SM")
        guard formatCode != nil && formatCode!.rangeOfCharacter(from: validFormatCodes) != nil
        else
        {
            print("Decoding barcode: Invalid format code \(formatCode ?? "Empty")")
            return nil
        }

        // Number of flights in this barcode - usually 1.
        let segments: String? = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 1))
        guard segments != nil && segments!.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
        else
        {
            print("Decoding barcode: Invalid segments \(segments ?? "Empty")")
            return nil
        }

        // This could get messy:
        let fullName = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 20)).split(separator: "/")
        let firstName = fullName.count > 1 ? String(fullName[1]).trimTrailing(.whitespaces) : ""
        let lastName = String(fullName[0]).trimTrailing(.whitespaces)

        // This section repeats, but we're only going to do it once for now
        // since I don't have a good example of a repeated one.
        _ = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 1))
        _ = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 7))
        let fromAirport = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 3))
        let toAirport = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 3))
        let carrier = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 3)).trimTrailing(.whitespaces)
        let flightNo = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 5)).trimTrailing(.whitespaces)

        // This is a weird one as it's in the Julian date calendar (days from the start of the year):
        // Will figure out a way of parsing this at some point...
        _ = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 3))

        // Not class of service, but the actual fare code.
        let fareClass = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 1))

        let seatNo = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 4))

        // The order you received your ticket. 00001 = first 'check in'.
        let checkInNo = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 5))

        // Eh, can probs be done better, but this works for now.
        var passengerStatus = "Unknown"
        let status = newBarcode.cutRange(bounds: newBarcode.rangeFromStart(length: 1))
        switch status
        {
        case "0", "2":
            passengerStatus = "notCheckedIn"
        case "1", "3":
            passengerStatus = "checkedIn"
        case "7":
            passengerStatus = "standby"
        case "4", "5", "6", "8", "9", "A":
            passengerStatus = "other"

        default:
            passengerStatus = "Unknown"
        }
        let decoded = carrier + flightNo + " " + firstName + lastName + " " + seatNo + " " + passengerStatus + " " + fareClass
        print("decoded data: \(decoded)")
        return decoded
    }
}

private extension String
{
    mutating func cutRange(bounds: Range<String.Index>) -> String
    {
        let substring = self.substring(with: bounds)
        removeSubrange(bounds)
        return substring
    }

    func rangeFromStart(length: Int) -> Range<String.Index>
    {
        return startIndex ..< index(startIndex, offsetBy: length)
    }

    func trimTrailing(_ characterSet: CharacterSet) -> String
    {
        if let range = rangeOfCharacter(from: characterSet, options: [.anchored, .backwards])
        {
            return substring(to: range.lowerBound).trimTrailing(characterSet)
        }
        return self
    }
}
