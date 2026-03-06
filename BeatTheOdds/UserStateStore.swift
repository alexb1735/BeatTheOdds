import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFirestoreSwift

class UserStateStore: ObservableObject {

    @Published var state: UserState = .default

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        listener = db.collection("users")
            .document(uid)
            .addSnapshotListener { snapshot, error in

                guard let snapshot = snapshot else { return }

                if let userState = try? snapshot.data(as: UserState.self) {
                    DispatchQueue.main.async {
                        self.state = userState
                    }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

}