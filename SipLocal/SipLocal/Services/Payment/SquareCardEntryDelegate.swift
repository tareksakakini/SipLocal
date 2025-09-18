import Foundation
import SquareInAppPaymentsSDK
import Combine

class SquareCardEntryDelegate: NSObject, ObservableObject, SQIPCardEntryViewControllerDelegate {
    
    @Published var cardDetails: SQIPCardDetails?
    @Published var wasCancelled = false
    
    func cardEntryViewController(_ cardEntryViewController: SQIPCardEntryViewController, didCompleteWith status: SQIPCardEntryCompletionStatus) {
        // Dismiss the card entry form
        cardEntryViewController.dismiss(animated: true, completion: nil)
        
        DispatchQueue.main.async {
            if status == .canceled {
                print("Card entry was canceled.")
                self.wasCancelled = true
            }
        }
    }

    func cardEntryViewController(_ cardEntryViewController: SQIPCardEntryViewController, didObtain cardDetails: SQIPCardDetails, completionHandler: @escaping (Error?) -> Void) {
        print("Obtained card nonce: \(cardDetails.nonce)")
        
        // This is where you would send the nonce to your backend server to charge the card.
        // For this example, we'll assume the server interaction is successful.
        // If it were to fail, you would call completionHandler with an error.
        completionHandler(nil)
        
        // Publish the successful card details.
        DispatchQueue.main.async {
            self.cardDetails = cardDetails
        }
    }
} 