//
//  DisplayViewModel.swift
//  SheridanBnb
//
//  Created by Winsome Tang on 2024-01-04.
//
import Foundation
import FirebaseFirestore

class DisplayViewModel: ObservableObject {
    @Published var wings: [Wing] = []
    @Published var availableClassrooms: [IdentifiableClassroom] = []
    @Published var wingIDs: [String] = ["All"]
    @Published var selectedWing: String? {
        didSet {
            fetchFilteredClassrooms(for: selectedWing)
        }
    }
    @Published var searchText = ""
    
    
    func sortedClassrooms(wingID: String?) -> [IdentifiableClassroom] {
        var classroomsToSort = wingID == nil ? availableClassrooms : availableClassrooms.filter { $0.wingID == wingID }
        classroomsToSort.sort {
            $0.classroomID.localizedStandardCompare($1.classroomID) == .orderedAscending
        }
        return classroomsToSort
    }
    
    func fetchClassroomsFromFirestore() {
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE" // for the day of the week
        let dayString = dateFormatter.string(from: currentDate)
        
        dateFormatter.dateFormat = "HH:mm" // for the current time
        let currentTime = dateFormatter.string(from: currentDate)

        let db = Firestore.firestore()
        db.collection("Winter2024").document("wings").getDocument { [weak self] document, error in
            if let error = error {
                print("Error fetching document: \(error.localizedDescription)")
                return
            }

            guard let document = document, document.exists else {
                print("Document does not exist")
                return
            }
            print("Document fetched successfully: \(document.documentID)")
            self?.decodeWingsDocument(document: document)

            DispatchQueue.main.async {
                self?.availableClassrooms = self?.wings.flatMap { wing in
                    wing.classrooms.compactMap { classroomID, classroom -> IdentifiableClassroom? in
                        let isAvailable = !(classroom.schedule[dayString]?.isClassroomOccupied(currentTime: currentTime) ?? false)
                        return isAvailable ? IdentifiableClassroom(wingID: wing.id, classroomID: classroomID) : nil
                    }
                } ?? []
                self?.wingIDs = ["All"] + (self?.wings.map { $0.id }.sorted() ?? [])
            }
        }
    }

    func fetchFilteredClassrooms(for wingID: String?) {
        // Assuming decodeWingsDocument has already populated the wings with the appropriate data
        // This function will filter available classrooms for a specific wing
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE" // for the day of the week
        let dayString = dateFormatter.string(from: currentDate)
        
        dateFormatter.dateFormat = "HH:mm" // for the current time
        let currentTime = dateFormatter.string(from: currentDate)

        availableClassrooms = wings.filter { $0.id == wingID }
            .flatMap { wing in
                wing.classrooms.compactMap { classroomID, classroom -> IdentifiableClassroom? in
                    let isAvailable = !(classroom.schedule[dayString]?.isClassroomOccupied(currentTime: currentTime) ?? false)
                    return isAvailable ? IdentifiableClassroom(wingID: wing.id, classroomID: classroomID) : nil
                }
            }
            .sorted {
                $0.classroomID.localizedStandardCompare($1.classroomID) == .orderedAscending
            }
        availableClassrooms = filterAvailableClassrooms(for: selectedWing)
    }


    // This new method will replace the resetAvailableClassrooms method
    func filterAndSortAvailableClassrooms(wingID: String?) -> [IdentifiableClassroom] {
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE" // for the day of the week
        let dayString = dateFormatter.string(from: currentDate)
        
        dateFormatter.dateFormat = "HH:mm" // for the current time
        let currentTime = dateFormatter.string(from: currentDate)
        
        var classrooms = [IdentifiableClassroom]()
        
        for wing in wings {
            guard wingID == nil || wing.id == wingID else { continue }
            for (classroomID, classroom) in wing.classrooms {
                let isAvailable = !(classroom.schedule[dayString]?.isClassroomOccupied(currentTime: currentTime) ?? false)
                if isAvailable || wingID == nil { // if "All" is selected or the classroom is available
                    classrooms.append(IdentifiableClassroom(wingID: wing.id, classroomID: classroomID))
                }
            }
        }
        
        return classrooms.sorted { $0.classroomID.localizedStandardCompare($1.classroomID) == .orderedAscending }
    }

    
    func filterAvailableClassrooms(for wingID: String? = nil) -> [IdentifiableClassroom] {
        print("filterAvailableClassrooms() is called for wing: \(wingID ?? "All")")
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE" // for the day of the week
        let dayString = dateFormatter.string(from: currentDate)
        
        dateFormatter.dateFormat = "HH:mm" // for the current time
        let currentTime = dateFormatter.string(from: currentDate)
        
        var unsortedClassrooms = [IdentifiableClassroom]()
        
        // Debug: print the wings and classrooms loaded
        print("Wings and classrooms loaded: \(wings)")
        
        for wing in wings {
            guard wingID == nil || wing.id == wingID else { continue }
            
            for (classroomID, classroom) in wing.classrooms {
                // Debug: print the day's schedule
                print("Checking schedule for classroom \(classroomID) on \(dayString) in wing \(wing.id)")
                if let daySchedule = classroom.schedule[dayString], !daySchedule.isEmpty {
                    let isOccupied = daySchedule.isClassroomOccupied(currentTime: currentTime)
                    // Debug: print whether the classroom is occupied or not
                    print("Classroom \(classroomID) is \(isOccupied ? "occupied" : "available") at \(currentTime)")
                    if !isOccupied {
                        unsortedClassrooms.append(IdentifiableClassroom(wingID: wing.id, classroomID: classroomID))
                    }
                } else {
                    // Debug: print that the classroom is available as no schedule was found
                    print("Classroom \(classroomID) is available as no schedule was found for \(dayString)")
                    unsortedClassrooms.append(IdentifiableClassroom(wingID: wing.id, classroomID: classroomID))
                }
            }
        }
        
        // Sort the filteredClassrooms before returning
        let sortedClassrooms = unsortedClassrooms.sorted {
            $0.classroomID.localizedStandardCompare($1.classroomID) == .orderedAscending
        }
        
        print("Available classrooms: \(sortedClassrooms.map { "\($0.wingID)-\($0.classroomID)" })")
        return sortedClassrooms
    }

    
    
    // Helper function to check if a classroom is occupied on a specific day
    private func isClassroomOccupied(daySchedule: [CourseTime], currentTime: String) -> Bool {
        daySchedule.contains { courseTime in
            courseTime.isTimeInRange(currentTime: currentTime)
            
        }
    }
    
    private func decodeWingsDocument(document: DocumentSnapshot) {
        guard let data = document.data() else {
            print("Document data was empty.")
            return
        }
        self.wings.removeAll()
        
        for (key, value) in data {
            print("Processing wing with key: \(key)")
            if let wingDict = value as? [String: Any], let classroomsDict = wingDict["classrooms"] as? [String: [String: Any]] {
                var classrooms = [String: Classroom]()
                
                // Sort the classroom keys before processing
                let sortedClassroomKeys = classroomsDict.keys.sorted {
                    $0.localizedStandardCompare($1) == .orderedAscending
                }
                
                for classroomKey in sortedClassroomKeys {
                    if let classroomValue = classroomsDict[classroomKey] {
                        print("Processing classroom with key: \(classroomKey)")
                        // Now using JSONSerialization to convert the classroomValue into Data
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: classroomValue)
                            // Decoding the Classroom object from jsonData instead of directly initializing
                            let classroom = try JSONDecoder().decode(Classroom.self, from: jsonData)
                            classrooms[classroomKey] = classroom
                            print("Decoded schedule for classroom \(classroomKey): \(classroom.schedule)")
                        } catch {
                            print("Error decoding classroom data for key: \(classroomKey), error: \(error)")
                        }
                    }
                }
                let wing = Wing(id: key, classrooms: classrooms)
                self.wings.append(wing)
                print("Wing added with ID: \(wing.id)")
            }
        }
        print("Finished processing document. Total wings: \(self.wings.count)")
    }
}


extension Array where Element == CourseTime {

    func isClassroomOccupied(currentTime: String) -> Bool {

        // If any course time includes the current time, the classroom is considered occupied
        for courseTime in self {
            if courseTime.isTimeInRange(currentTime: currentTime) {
                return true
            }
        }
        // If no course times include the current time, the classroom is not occupied
        return false
    }
}
