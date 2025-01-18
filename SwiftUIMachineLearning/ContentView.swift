import SwiftUI
import CoreML

extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height),
                                         kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                                width: Int(self.size.width),
                                height: Int(self.size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

struct ContentView: View {
    let images = ["n101", "n001", "n002", "n004", "n100", "n000", "n102", "n700", "n701", "n703"]
    var imageClassifier: CatDogImageClassifierModel?
    @State private var currentIndex = 0
    @State private var predictionResult: (label: String, confidence: Double) = ("", 0.0)
    
    init() {
        do {
            imageClassifier = try CatDogImageClassifierModel(configuration: MLModelConfiguration())
        } catch {
            print("Model initialization error: \(error)")
        }
    }
    
    var isPreviousButtonValid: Bool {
        currentIndex != 0
    }
    
    var isNextButtonValid: Bool {
        currentIndex < images.count - 1
    }
    
    func predictImage() {
        guard let uiImage = UIImage(named: images[currentIndex]) else {
            print("Failed to load image")
            return
        }
        guard let pixelBuffer = uiImage.toCVPixelBuffer() else {
            print("Failed to create pixel buffer")
            return
        }
        
        do {
            let result = try imageClassifier?.prediction(image: pixelBuffer)
            if let predictions = result?.targetProbability {
                // Sort the predictions by confidence in descending order
                let sortedPredictions = predictions.sorted { $0.value > $1.value }
                
                if let topPrediction = sortedPredictions.first {
                    DispatchQueue.main.async {
                        let newLabel = topPrediction.key
                            .replacingOccurrences(of: "_", with: " ")
                            .capitalized
                        let newConfidence = topPrediction.value
                        
                        // Update the state with the highest confidence prediction
                        predictionResult = (newLabel, newConfidence)
                        print("Prediction: \(predictionResult.label) (\(predictionResult.confidence))")
                    }
                }
            }
        } catch {
            print("Prediction error: \(error)")
        }
    }
    var body: some View {
        ZStack {
            Image("monofondo")
                .resizable()
                .ignoresSafeArea()
                .scaledToFill()
            
            VStack(spacing: 20) {
                Text("Identificador de Monos 🐒")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .shadow(radius: 3)
                    
                    Image(images[currentIndex])
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
                .frame(width: 280, height: 280)
                
                Text("es un mono")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(String(format: "Confianza: %.2f%%", predictionResult.confidence * 100))
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    Button(action: {
                        if isPreviousButtonValid {
                            currentIndex -= 1
                            predictImage()
                        }
                    }) {
                        Text("Anterior")
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isPreviousButtonValid)
                    
                    Button(action: {
                        if isNextButtonValid {
                            currentIndex += 1
                            predictImage()
                        }
                    }) {
                        Text("Siguiente")
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isNextButtonValid)
                }
            }
            .padding()
        }
        .onAppear {
            predictImage()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
