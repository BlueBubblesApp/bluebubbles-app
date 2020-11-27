import Flutter
import UIKit
import Contacts
import ContactsUI

@available(iOS 9.0, *)
public class SwiftContactsServicePlugin: NSObject, FlutterPlugin, CNContactViewControllerDelegate, CNContactPickerDelegate {
    private var result: FlutterResult? = nil
    private var localizedLabels: Bool = true
    private let rootViewController: UIViewController
    static let FORM_OPERATION_CANCELED: Int = 1
    static let FORM_COULD_NOT_BE_OPEN: Int = 2
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "github.com/clovisnicolas/flutter_contacts", binaryMessenger: registrar.messenger())
        let rootViewController = UIApplication.shared.delegate!.window!!.rootViewController!;
        let instance = SwiftContactsServicePlugin(rootViewController)
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.preLoadContactView()
    }

    init(_ rootViewController: UIViewController) {
        self.rootViewController = rootViewController
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getContacts":
            let arguments = call.arguments as! [String:Any]
            result(getContacts(query: (arguments["query"] as? String), withThumbnails: arguments["withThumbnails"] as! Bool,
                               photoHighResolution: arguments["photoHighResolution"] as! Bool, phoneQuery:  false, orderByGivenName: arguments["orderByGivenName"] as! Bool,
                               localizedLabels: arguments["iOSLocalizedLabels"] as! Bool ))
        case "getContactsForPhone":
            let arguments = call.arguments as! [String:Any]
            result(
                getContacts(
                    query: (arguments["phone"] as? String),
                    withThumbnails: arguments["withThumbnails"] as! Bool,
                    photoHighResolution: arguments["photoHighResolution"] as! Bool,
                    phoneQuery: true,
                    orderByGivenName: arguments["orderByGivenName"] as! Bool,
                    localizedLabels: arguments["iOSLocalizedLabels"] as! Bool
                )
            )
        case "getContactsForEmail":
            let arguments = call.arguments as! [String:Any]
            result(
                getContacts(
                    query: (arguments["email"] as? String),
                    withThumbnails: arguments["withThumbnails"] as! Bool,
                    photoHighResolution: arguments["photoHighResolution"] as! Bool,
                    phoneQuery: false,
                    emailQuery: true,
                    orderByGivenName: arguments["orderByGivenName"] as! Bool,
                    localizedLabels: arguments["iOSLocalizedLabels"] as! Bool
                )
            )
        case "addContact":
            let contact = dictionaryToContact(dictionary: call.arguments as! [String : Any])

            let addResult = addContact(contact: contact)
            if (addResult == "") {
                result(nil)
            }
            else {
                result(FlutterError(code: "", message: addResult, details: nil))
            }
        case "deleteContact":
            if(deleteContact(dictionary: call.arguments as! [String : Any])){
                result(nil)
            }
            else{
                result(FlutterError(code: "", message: "Failed to delete contact, make sure it has a valid identifier", details: nil))
            }
        case "updateContact":
            if(updateContact(dictionary: call.arguments as! [String: Any])) {
                result(nil)
            }
            else {
                result(FlutterError(code: "", message: "Failed to update contact, make sure it has a valid identifier", details: nil))
            }
         case "openContactForm":
            let arguments = call.arguments as! [String:Any]
            localizedLabels = arguments["iOSLocalizedLabels"] as! Bool
            self.result = result
            _ = openContactForm()
         case "openExistingContact":
            let arguments = call.arguments as! [String : Any]
            let contact = arguments["contact"] as! [String : Any]
            localizedLabels = arguments["iOSLocalizedLabels"] as! Bool
            self.result = result
            _ = openExistingContact(contact: contact, result: result)
        case "openDeviceContactPicker":
            let arguments = call.arguments as! [String : Any]
            openDeviceContactPicker(arguments: arguments, result: result);
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func getContacts(query : String?, withThumbnails: Bool, photoHighResolution: Bool, phoneQuery: Bool, emailQuery: Bool = false, orderByGivenName: Bool, localizedLabels: Bool) -> [[String:Any]]{

        var contacts : [CNContact] = []
        var result = [[String:Any]]()

        //Create the store, keys & fetch request
        let store = CNContactStore()
        var keys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                    CNContactEmailAddressesKey,
                    CNContactPhoneNumbersKey,
                    CNContactFamilyNameKey,
                    CNContactGivenNameKey,
                    CNContactMiddleNameKey,
                    CNContactNamePrefixKey,
                    CNContactNameSuffixKey,
                    CNContactPostalAddressesKey,
                    CNContactOrganizationNameKey,
                    CNContactJobTitleKey,
                    CNContactBirthdayKey] as [Any]

        if(withThumbnails){
            if(photoHighResolution){
                keys.append(CNContactImageDataKey)
            } else {
                keys.append(CNContactThumbnailImageDataKey)
            }
        }

        let fetchRequest = CNContactFetchRequest(keysToFetch: keys as! [CNKeyDescriptor])
        // Set the predicate if there is a query
        if query != nil && !phoneQuery && !emailQuery {
            fetchRequest.predicate = CNContact.predicateForContacts(matchingName: query!)
        }

        if #available(iOS 11, *) {
            if query != nil && phoneQuery {
                let phoneNumberPredicate = CNPhoneNumber(stringValue: query!)
                fetchRequest.predicate = CNContact.predicateForContacts(matching: phoneNumberPredicate)
            } else if query != nil && emailQuery {
                fetchRequest.predicate = CNContact.predicateForContacts(matchingEmailAddress: query!)
            }
        }

        // Fetch contacts
        do{
            try store.enumerateContacts(with: fetchRequest, usingBlock: { (contact, stop) -> Void in

                if phoneQuery {
                    if #available(iOS 11, *) {
                        contacts.append(contact)
                    } else if query != nil && self.has(contact: contact, phone: query!){
                        contacts.append(contact)
                    }
                } else if emailQuery {
                    if #available(iOS 11, *) {
                        contacts.append(contact)
                    } else if query != nil && (contact.emailAddresses.contains { $0.value.caseInsensitiveCompare(query!) == .orderedSame}) {
                        contacts.append(contact)
                    }
                } else {
                    contacts.append(contact)
                }

            })
        }
        catch let error as NSError {
            print(error.localizedDescription)
            return result
        }

        if (orderByGivenName) {
            contacts = contacts.sorted { (contactA, contactB) -> Bool in
                contactA.givenName.lowercased() < contactB.givenName.lowercased()
            }
        }

        // Transform the CNContacts into dictionaries
        for contact : CNContact in contacts{
            result.append(contactToDictionary(contact: contact, localizedLabels: localizedLabels))
        }

        return result
    }

    private func has(contact: CNContact, phone: String) -> Bool {
        if (!contact.phoneNumbers.isEmpty) {
            let phoneNumberToCompareAgainst = phone.components(separatedBy: NSCharacterSet.decimalDigits.inverted).joined(separator: "")
            for phoneNumber in contact.phoneNumbers {

                if let phoneNumberStruct = phoneNumber.value as CNPhoneNumber? {
                    let phoneNumberString = phoneNumberStruct.stringValue
                    let phoneNumberToCompare = phoneNumberString.components(separatedBy: NSCharacterSet.decimalDigits.inverted).joined(separator: "")
                    if phoneNumberToCompare == phoneNumberToCompareAgainst {
                        return true
                    }
                }
            }
        }
        return false
    }

    func addContact(contact : CNMutableContact) -> String {
        let store = CNContactStore()
        do {
            let saveRequest = CNSaveRequest()
            saveRequest.add(contact, toContainerWithIdentifier: nil)
            try store.execute(saveRequest)
        }
        catch {
            return error.localizedDescription
        }
        return ""
    }

    func openContactForm() -> [String:Any]? {
        let contact = CNMutableContact.init()
        let controller = CNContactViewController.init(forNewContact:contact)
        controller.delegate = self
        DispatchQueue.main.async {
         let navigation = UINavigationController .init(rootViewController: controller)
         let viewController : UIViewController? = UIApplication.shared.delegate?.window??.rootViewController
            viewController?.present(navigation, animated:true, completion: nil)
        }
        return nil
    }
    
    func preLoadContactView() {
        DispatchQueue.main.asyncAfter(deadline: .now()+5) {
            NSLog("Preloading CNContactViewController")
            let contactViewController = CNContactViewController.init(forNewContact: nil)
        }
    }
    
    @objc func cancelContactForm() {
        if let result = self.result {
            let viewController : UIViewController? = UIApplication.shared.delegate?.window??.rootViewController
            viewController?.dismiss(animated: true, completion: nil)
            result(SwiftContactsServicePlugin.FORM_OPERATION_CANCELED)
            self.result = nil
        }
    }
    
    public func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        viewController.dismiss(animated: true, completion: nil)
        if let result = self.result {
            if let contact = contact {
                result(contactToDictionary(contact: contact, localizedLabels: localizedLabels))
            } else {
                result(SwiftContactsServicePlugin.FORM_OPERATION_CANCELED)
            }
            self.result = nil
        }
    }

    func openExistingContact(contact: [String:Any], result: FlutterResult ) ->  [String:Any]? {
         let store = CNContactStore()
         do {
            // Check to make sure dictionary has an identifier
             guard let identifier = contact["identifier"] as? String else{
                 result(SwiftContactsServicePlugin.FORM_COULD_NOT_BE_OPEN)
                 return nil;
             }
            let backTitle = contact["backTitle"] as? String
            
             let keysToFetch = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                                CNContactIdentifierKey,
                                CNContactEmailAddressesKey,
                                CNContactBirthdayKey,
                                CNContactImageDataKey,
                                CNContactPhoneNumbersKey,
                                CNContactViewController.descriptorForRequiredKeys()
                ] as! [CNKeyDescriptor]
            let cnContact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
            let viewController = CNContactViewController(for: cnContact)

            viewController.navigationItem.backBarButtonItem = UIBarButtonItem.init(title: backTitle == nil ? "Cancel" : backTitle, style: UIBarButtonItem.Style.plain, target: self, action: #selector(cancelContactForm))
             viewController.delegate = self
            DispatchQueue.main.async {
                let navigation = UINavigationController .init(rootViewController: viewController)
                var currentViewController = UIApplication.shared.keyWindow?.rootViewController
                while let nextView = currentViewController?.presentedViewController {
                    currentViewController = nextView
                }
                let activityIndicatorView = UIActivityIndicatorView.init(style: UIActivityIndicatorView.Style.gray)
                activityIndicatorView.frame = (UIApplication.shared.keyWindow?.frame)!
                activityIndicatorView.startAnimating()
                activityIndicatorView.backgroundColor = UIColor.white
                navigation.view.addSubview(activityIndicatorView)
                currentViewController!.present(navigation, animated: true, completion: nil)
                
                DispatchQueue.main.asyncAfter(deadline: .now()+0.5 ){
                    activityIndicatorView.removeFromSuperview()
                }
            }
            return nil
         } catch {
            NSLog(error.localizedDescription)
            result(SwiftContactsServicePlugin.FORM_COULD_NOT_BE_OPEN)
            return nil
         }
     }
     
    func openDeviceContactPicker(arguments arguments: [String:Any], result: @escaping FlutterResult) {
        localizedLabels = arguments["iOSLocalizedLabels"] as! Bool
        self.result = result
        
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        //contactPicker!.displayedPropertyKeys = [CNContactPhoneNumbersKey];
        DispatchQueue.main.async {
            self.rootViewController.present(contactPicker, animated: true, completion: nil)
        }
    }

    //MARK:- CNContactPickerDelegate Method

    public func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        if let result = self.result {
            result(contactToDictionary(contact: contact, localizedLabels: localizedLabels))
            self.result = nil
        }
    }

    public func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        if let result = self.result {
            result(SwiftContactsServicePlugin.FORM_OPERATION_CANCELED)
            self.result = nil
        }
    }
    

    func deleteContact(dictionary : [String:Any]) -> Bool{
        guard let identifier = dictionary["identifier"] as? String else{
            return false;
        }
        let store = CNContactStore()
        let keys = [CNContactIdentifierKey as NSString]
        do{
            if let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys).mutableCopy() as? CNMutableContact{
                let request = CNSaveRequest()
                request.delete(contact)
                try store.execute(request)
            }
        }
        catch{
            print(error.localizedDescription)
            return false;
        }
        return true;
    }

    func updateContact(dictionary : [String:Any]) -> Bool{

        // Check to make sure dictionary has an identifier
        guard let identifier = dictionary["identifier"] as? String else{
            return false;
        }

        let store = CNContactStore()
        let keys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                    CNContactEmailAddressesKey,
                    CNContactPhoneNumbersKey,
                    CNContactFamilyNameKey,
                    CNContactGivenNameKey,
                    CNContactMiddleNameKey,
                    CNContactNamePrefixKey,
                    CNContactNameSuffixKey,
                    CNContactPostalAddressesKey,
                    CNContactOrganizationNameKey,
                    CNContactImageDataKey,
                    CNContactJobTitleKey] as [Any]
        do {
            // Check if the contact exists
            if let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys as! [CNKeyDescriptor]).mutableCopy() as? CNMutableContact{

                /// Update the contact that was retrieved from the store
                //Simple fields
                contact.givenName = dictionary["givenName"] as? String ?? ""
                contact.familyName = dictionary["familyName"] as? String ?? ""
                contact.middleName = dictionary["middleName"] as? String ?? ""
                contact.namePrefix = dictionary["prefix"] as? String ?? ""
                contact.nameSuffix = dictionary["suffix"] as? String ?? ""
                contact.organizationName = dictionary["company"] as? String ?? ""
                contact.jobTitle = dictionary["jobTitle"] as? String ?? ""
                contact.imageData = (dictionary["avatar"] as? FlutterStandardTypedData)?.data

                //Phone numbers
                if let phoneNumbers = dictionary["phones"] as? [[String:String]]{
                    var updatedPhoneNumbers = [CNLabeledValue<CNPhoneNumber>]()
                    for phone in phoneNumbers where phone["value"] != nil {
                        updatedPhoneNumbers.append(CNLabeledValue(label:getPhoneLabel(label: phone["label"]),value:CNPhoneNumber(stringValue: phone["value"]!)))
                    }
                    contact.phoneNumbers = updatedPhoneNumbers
                }

                //Emails
                if let emails = dictionary["emails"] as? [[String:String]]{
                    var updatedEmails = [CNLabeledValue<NSString>]()
                    for email in emails where nil != email["value"] {
                        let emailLabel = email["label"] ?? ""
                        updatedEmails.append(CNLabeledValue(label: getCommonLabel(label: emailLabel), value: email["value"]! as NSString))
                    }
                    contact.emailAddresses = updatedEmails
                }

                //Postal addresses
                if let postalAddresses = dictionary["postalAddresses"] as? [[String:String]]{
                    var updatedPostalAddresses = [CNLabeledValue<CNPostalAddress>]()
                    for postalAddress in postalAddresses{
                        let newAddress = CNMutablePostalAddress()
                        newAddress.street = postalAddress["street"] ?? ""
                        newAddress.city = postalAddress["city"] ?? ""
                        newAddress.postalCode = postalAddress["postcode"] ?? ""
                        newAddress.country = postalAddress["country"] ?? ""
                        newAddress.state = postalAddress["region"] ?? ""
                        let label = postalAddress["label"] ?? ""
                        updatedPostalAddresses.append(CNLabeledValue(label: getCommonLabel(label: label), value: newAddress))
                    }
                    contact.postalAddresses = updatedPostalAddresses
                }

                // Attempt to update the contact
                let request = CNSaveRequest()
                request.update(contact)
                try store.execute(request)
            }
        }
        catch {
            print(error.localizedDescription)
            return false;
        }
        return true;
    }

    func dictionaryToContact(dictionary : [String:Any]) -> CNMutableContact{
        let contact = CNMutableContact()

        //Simple fields
        contact.givenName = dictionary["givenName"] as? String ?? ""
        contact.familyName = dictionary["familyName"] as? String ?? ""
        contact.middleName = dictionary["middleName"] as? String ?? ""
        contact.namePrefix = dictionary["prefix"] as? String ?? ""
        contact.nameSuffix = dictionary["suffix"] as? String ?? ""
        contact.organizationName = dictionary["company"] as? String ?? ""
        contact.jobTitle = dictionary["jobTitle"] as? String ?? ""
        if let avatarData = (dictionary["avatar"] as? FlutterStandardTypedData)?.data {
            contact.imageData = avatarData
        }

        //Phone numbers
        if let phoneNumbers = dictionary["phones"] as? [[String:String]]{
            for phone in phoneNumbers where phone["value"] != nil {
                contact.phoneNumbers.append(CNLabeledValue(label:getPhoneLabel(label:phone["label"]),value:CNPhoneNumber(stringValue:phone["value"]!)))
            }
        }

        //Emails
        if let emails = dictionary["emails"] as? [[String:String]]{
            for email in emails where nil != email["value"] {
                let emailLabel = email["label"] ?? ""
                contact.emailAddresses.append(CNLabeledValue(label:getCommonLabel(label: emailLabel), value:email["value"]! as NSString))
            }
        }

        //Postal addresses
        if let postalAddresses = dictionary["postalAddresses"] as? [[String:String]]{
            for postalAddress in postalAddresses{
                let newAddress = CNMutablePostalAddress()
                newAddress.street = postalAddress["street"] ?? ""
                newAddress.city = postalAddress["city"] ?? ""
                newAddress.postalCode = postalAddress["postcode"] ?? ""
                newAddress.country = postalAddress["country"] ?? ""
                newAddress.state = postalAddress["region"] ?? ""
                let label = postalAddress["label"] ?? ""
                contact.postalAddresses.append(CNLabeledValue(label: getCommonLabel(label: label), value: newAddress))
            }
        }

        //BIRTHDAY
        if let birthday = dictionary["birthday"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let date = formatter.date(from: birthday)!
            contact.birthday = Calendar.current.dateComponents([.year, .month, .day], from: date)
        }

        return contact
    }

    func contactToDictionary(contact: CNContact, localizedLabels: Bool) -> [String:Any]{

        var result = [String:Any]()

        //Simple fields
        result["identifier"] = contact.identifier
        result["displayName"] = CNContactFormatter.string(from: contact, style: CNContactFormatterStyle.fullName)
        result["givenName"] = contact.givenName
        result["familyName"] = contact.familyName
        result["middleName"] = contact.middleName
        result["prefix"] = contact.namePrefix
        result["suffix"] = contact.nameSuffix
        result["company"] = contact.organizationName
        result["jobTitle"] = contact.jobTitle
        if contact.isKeyAvailable(CNContactThumbnailImageDataKey) {
            if let avatarData = contact.thumbnailImageData {
                result["avatar"] = FlutterStandardTypedData(bytes: avatarData)
            }
        }
        if contact.isKeyAvailable(CNContactImageDataKey) {
            if let avatarData = contact.imageData {
                result["avatar"] = FlutterStandardTypedData(bytes: avatarData)
            }
        }

        //Phone numbers
        var phoneNumbers = [[String:String]]()
        for phone in contact.phoneNumbers{
            var phoneDictionary = [String:String]()
            phoneDictionary["value"] = phone.value.stringValue
            phoneDictionary["label"] = "other"
            if let label = phone.label{
                phoneDictionary["label"] = localizedLabels ? CNLabeledValue<NSString>.localizedString(forLabel: label) : getRawPhoneLabel(label);
            }
            phoneNumbers.append(phoneDictionary)
        }
        result["phones"] = phoneNumbers

        //Emails
        var emailAddresses = [[String:String]]()
        for email in contact.emailAddresses{
            var emailDictionary = [String:String]()
            emailDictionary["value"] = String(email.value)
            emailDictionary["label"] = "other"
            if let label = email.label{
                emailDictionary["label"] = localizedLabels ? CNLabeledValue<NSString>.localizedString(forLabel: label) : getRawCommonLabel(label);
            }
            emailAddresses.append(emailDictionary)
        }
        result["emails"] = emailAddresses

        //Postal addresses
        var postalAddresses = [[String:String]]()
        for address in contact.postalAddresses{
            var addressDictionary = [String:String]()
            addressDictionary["label"] = ""
            if let label = address.label{
                addressDictionary["label"] = localizedLabels ? CNLabeledValue<NSString>.localizedString(forLabel: label) : getRawCommonLabel(label);
            }
            addressDictionary["street"] = address.value.street
            addressDictionary["city"] = address.value.city
            addressDictionary["postcode"] = address.value.postalCode
            addressDictionary["region"] = address.value.state
            addressDictionary["country"] = address.value.country

            postalAddresses.append(addressDictionary)
        }
        result["postalAddresses"] = postalAddresses

        //BIRTHDAY
        if let birthday : Date = contact.birthday?.date {
            let formatter = DateFormatter()
            let year = Calendar.current.component(.year, from: birthday)
            formatter.dateFormat = year == 1 ? "--MM-dd" : "yyyy-MM-dd";
            result["birthday"] = formatter.string(from: birthday)
        }

        return result
    }

    func getPhoneLabel(label: String?) -> String{
        let labelValue = label ?? ""
        switch(labelValue){
        case "main": return CNLabelPhoneNumberMain
        case "mobile": return CNLabelPhoneNumberMobile
        case "iPhone": return CNLabelPhoneNumberiPhone
        case "work": return CNLabelWork
        case "home": return CNLabelHome
        case "other": return CNLabelOther
        default: return labelValue
        }
    }

    func getCommonLabel(label:String?) -> String{
        let labelValue = label ?? ""
        switch(labelValue){
        case "work": return CNLabelWork
        case "home": return CNLabelHome
        case "other": return CNLabelOther
        default: return labelValue
        }
    }

    func getRawPhoneLabel(_ label: String?) -> String{
        let labelValue = label ?? ""
        switch(labelValue){
            case CNLabelPhoneNumberMain: return "main"
            case CNLabelPhoneNumberMobile: return "mobile"
            case CNLabelPhoneNumberiPhone: return "iPhone"
            case CNLabelWork: return "work"
            case CNLabelHome: return "home"
            case CNLabelOther: return "other"
            default: return labelValue
        }
    }

    func getRawCommonLabel(_ label: String?) -> String{
        let labelValue = label ?? ""
        switch(labelValue){
            case CNLabelWork: return "work"
            case CNLabelHome: return "home"
            case CNLabelOther: return "other"
            default: return labelValue
        }
    }

}
