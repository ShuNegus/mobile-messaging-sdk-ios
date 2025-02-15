//
//  TestUtils.swift
//  MobileMessaging
//
//  Created by Andrey K. on 21/03/16.
//

import Foundation
@testable import MobileMessaging

extension MobileMessaging {
	var isRegistrationStatusNeedSync: Bool {
		return Installation.delta["isPushRegistrationEnabled"] != nil
	}

	var isPushRegistrationEnabled: Bool {
		set {
			let di = self.dirtyInstallation()
			di.isPushRegistrationEnabled = newValue
			di.archiveDirty()
		}
		get {
			return self.resolveInstallation().isPushRegistrationEnabled
		}
	}

	var pushRegistrationId: String? {
		set {
			Installation.modifyAll { (installation) in
				installation.pushRegistrationId = newValue
			}
		}
		get {
			return self.resolveInstallation().pushRegistrationId
		}
	}

	var pushServiceToken: String? {
		set {
			let di = self.dirtyInstallation()
			di.pushServiceToken = newValue
			di.archiveDirty()
		}
		get {
			return self.resolveInstallation().pushRegistrationId
		}
	}

	var isPrimaryDevice: Bool {
		set {
			let di = self.dirtyInstallation()
			di.isPrimaryDevice = newValue
			di.archiveDirty()
		}
		get {
			return self.resolveInstallation().isPrimaryDevice
		}
	}

	var systemDataHash: Int64 {
		set {
			let id = self.internalData()
			id.systemDataHash = newValue
			id.archiveCurrent()
		}
		get {
			return self.internalData().systemDataHash
		}
	}
}

struct MMTestConstants {
	static let kTestInvalidInternalID = "someNonexistentInternalID"
	static let kTestCorrectInternalID = "someExistingInternalID"
	static let kTestValidMSISDN = "79697162937"
	static let kTestInvalidMSISDN = "9697162937"
	static let kTestValidEmail = "john@mail.com"
	static let kTestInvalidEmail = "john@mail,com"
	static let kTestCorrectApplicationCode = "someCorrectApplicationID"
	static let kTestWrongApplicationCode = "someWrongApplicationID"
	static let kTestCurrentRegistrationId = "fffe73006f006d00650054006f006b0065006e003200"
	static let kTestOldRegistrationId = "fffe73006f006d00650054006f006b0065006e00"
}

extension MobileMessaging {
	func setupApiSessionManagerStubbed() {
		MobileMessaging.sharedInstance?.remoteApiProvider = RemoteAPIProviderStub()
	}
}

class RemoteGeoAPIProviderStub : GeoRemoteAPIProvider {
	var isOffline: Bool = false
	init() {
		super.init(sessionManager: SessionManagerStubBase())
	}

	var reportGeoEventClosure: ((String, String, [GeoEventReportData], [MMGeoMessage]) -> GeoEventReportingResult)? = nil

	override func reportGeoEvent(applicationCode: String, pushRegistrationId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage], completion: @escaping (GeoEventReportingResult) -> Void) {

		if let reportGeoEventClosure = reportGeoEventClosure {
			if isOffline {
				reportGeoEventClosure(applicationCode, pushRegistrationId, eventsDataList, geoMessages)
				completion(GeoEventReportingResult.Failure(MMInternalErrorType.UnknownError.foundationError))
			} else {
				completion(reportGeoEventClosure(applicationCode, pushRegistrationId, eventsDataList, geoMessages))
			}
		} else {
			if isOffline {
				completion(GeoEventReportingResult.Failure(MMInternalErrorType.UnknownError.foundationError))
			} else {
				super.reportGeoEvent(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, eventsDataList: eventsDataList, geoMessages: geoMessages, completion: completion)
			}
		}
	}
}

class RemoteAPIProviderStub : RemoteAPIProvider {

	init() {
		super.init(sessionManager: SessionManagerStubBase())
	}

	var sendSeenStatusClosure: ((String, _ pushRegistrationId: String?, _ seenList: [SeenData]) -> SeenStatusSendingResult)? = nil
	var sendMessagesClosure: ((String, _ pushRegistrationId: String, _ messages: [MOMessage]) -> MOMessageSendingResult)? = nil
	var syncMessagesClosure: ((String, _ pushRegistrationId: String, _ archiveMsgIds: [String]?, _ dlrMsgIds: [String]?) -> MessagesSyncResult)? = nil
	var fetchRecentLibraryVersionClosure: ((String, _ pushRegistrationId: String?) -> LibraryVersionResult)? = nil
	var depersonalizeClosure: ((String, _ pushRegistrationId: String, _ pushRegistrationIdToDepersonalize: String) -> DepersonalizeResult)? = nil
	var personalizeClosure: ((String, _ pushRegistrationId: String, _ body: RequestBody, _ forceDepersonalize: Bool) -> PersonalizeResult)? = nil
	var patchOtherInstanceClosure: ((String, _ authPushRegistrationId: String, _ pushRegistrationId: String, _ body: RequestBody) -> UpdateInstanceDataResult)? = nil
	var postInstanceClosure: ((String, RequestBody) -> FetchInstanceDataResult)? = nil
	var patchInstanceClosure: ((String, String, String, RequestBody) -> UpdateInstanceDataResult)? = nil
	var getInstanceClosure: ((String, String) -> FetchInstanceDataResult)? = nil
	var deleteInstanceClosure: ((String, String, String) -> UpdateInstanceDataResult)? = nil
	var patchUserClosure: ((String, String, RequestBody) -> UpdateUserDataResult)? = nil
	var getUserClosure: ((String, String) -> FetchUserDataResult)? = nil

	override func sendSeenStatus(applicationCode: String, pushRegistrationId: String?, seenList: [SeenData], completion: @escaping (SeenStatusSendingResult) -> Void) {
		if let sendSeenStatusClosure = sendSeenStatusClosure {
			completion(sendSeenStatusClosure(applicationCode,pushRegistrationId,seenList))
		} else {
			super.sendSeenStatus(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, seenList: seenList, completion: completion)
		}
	}

	override func sendMessages(applicationCode: String, pushRegistrationId: String, messages: [MOMessage], completion: @escaping (MOMessageSendingResult) -> Void) {
		if let sendMessagesClosure = sendMessagesClosure {
			completion(sendMessagesClosure(applicationCode, pushRegistrationId,messages))
		} else {
			super.sendMessages(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, messages: messages, completion: completion)
		}
	}

	override func syncMessages(applicationCode: String, pushRegistrationId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?, completion: @escaping (MessagesSyncResult) -> Void) {
		if let syncMessagesClosure = syncMessagesClosure {
			completion(syncMessagesClosure(applicationCode,pushRegistrationId,archiveMsgIds,dlrMsgIds))
		} else {
			super.syncMessages(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, archiveMsgIds: archiveMsgIds, dlrMsgIds: dlrMsgIds, completion: completion)
		}
	}

	override func fetchRecentLibraryVersion(applicationCode: String, pushRegistrationId: String?, completion: @escaping (LibraryVersionResult) -> Void) {
		if let fetchRecentLibraryVersionClosure = fetchRecentLibraryVersionClosure {
			completion(fetchRecentLibraryVersionClosure(applicationCode,pushRegistrationId))
		} else {
			super.fetchRecentLibraryVersion(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, completion: completion)
		}
	}

	override func depersonalize(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String, completion: @escaping (DepersonalizeResult) -> Void) {
		if let depersonalizeClosure = depersonalizeClosure {
			completion(depersonalizeClosure(applicationCode,pushRegistrationId,pushRegistrationIdToDepersonalize))
		} else {
			super.depersonalize(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, pushRegistrationIdToDepersonalize: pushRegistrationIdToDepersonalize, completion: completion)
		}
	}

	override func personalize(applicationCode: String, pushRegistrationId: String, body: RequestBody, forceDepersonalize: Bool, completion: @escaping (PersonalizeResult) -> Void) {
		if let personalizeClosure = personalizeClosure {
			completion(personalizeClosure(applicationCode, pushRegistrationId,body,forceDepersonalize))
		} else {
			super.personalize(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body, forceDepersonalize: forceDepersonalize, completion: completion)
		}
	}

	override func patchInstance(applicationCode: String, authPushRegistrationId: String, refPushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		if let patchInstanceClosure = patchInstanceClosure {
			completion(patchInstanceClosure(applicationCode, authPushRegistrationId, refPushRegistrationId, body))
		} else {
			super.patchInstance(applicationCode: applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: refPushRegistrationId, body: body, completion: completion)
		}
	}

	override func patchOtherInstance(applicationCode: String, authPushRegistrationId: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		if let patchOtherInstanceClosure = patchOtherInstanceClosure {
			completion(patchOtherInstanceClosure(applicationCode,authPushRegistrationId,pushRegistrationId,body))
		} else {
			super.patchOtherInstance(applicationCode: applicationCode, authPushRegistrationId: authPushRegistrationId, pushRegistrationId: pushRegistrationId, body: body, completion: completion)
		}
	}

	override func getInstance(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchInstanceDataResult) -> Void) {
		if let getInstanceClosure = getInstanceClosure {
			completion(getInstanceClosure(applicationCode, pushRegistrationId))
		} else {
			super.getInstance(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, completion: completion)
		}
	}

	override func postInstance(applicationCode: String, body: RequestBody, completion: @escaping (FetchInstanceDataResult) -> Void) {
		if let postInstanceClosure = postInstanceClosure {
			completion(postInstanceClosure(applicationCode, body))
		} else {
			super.postInstance(applicationCode: applicationCode, body: body, completion: completion)
		}
	}

	override func deleteInstance(applicationCode: String, pushRegistrationId: String, expiredPushRegistrationId: String, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		if let deleteInstanceClosure = deleteInstanceClosure {
			completion(deleteInstanceClosure(applicationCode, pushRegistrationId, expiredPushRegistrationId))
		} else {
			super.deleteInstance(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, expiredPushRegistrationId: expiredPushRegistrationId, completion: completion)
		}
	}

	override func patchUser(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateUserDataResult) -> Void) {
		if let patchUserClosure = patchUserClosure {
			completion(patchUserClosure(applicationCode, pushRegistrationId, body))
		} else {
			super.patchUser(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body, completion: completion)
		}
	}

	override func getUser(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchUserDataResult) -> Void) {
		if let getUserClosure = getUserClosure {
			completion(getUserClosure(applicationCode, pushRegistrationId))
		} else {
			super.getUser(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, completion: completion)
		}

	}
}

class SessionManagerOfflineStubBase : DynamicBaseUrlHTTPSessionManager {
	init() {
		super.init(baseURL: URL(string: "https://initial-stub.com")!, sessionConfiguration: nil, appGroupId: nil)
	}

	override func sendRequest<R: RequestData>(_ request: R, completion: @escaping (JSON?, NSError?) -> Void) {
		completion(nil, MMInternalErrorType.UnknownError.foundationError)
	}
}

class SessionManagerStubBase : DynamicBaseUrlHTTPSessionManager {
	init() {
		super.init(baseURL: URL(string: "https://initial-stub.com")!, sessionConfiguration: nil, appGroupId: nil)
	}

	override func sendRequest<R: RequestData>(_ request: R, completion: @escaping (JSON?, NSError?) -> Void) {
		if let responseJSON = Mocks.mockedResponseForRequest(request: request, appCode: request.applicationCode, pushRegistrationId: request.pushRegistrationId) {

			let statusCode = responseJSON[MockKeys.responseStatus].intValue
			switch statusCode {
			case 0..<400:
				completion(responseJSON, nil)
			case 400..<600:
				if let requestError = RequestError(json: responseJSON) {
					completion(nil, requestError.foundationError)
				} else {
					completion(nil, MMInternalErrorType.UnknownError.foundationError)
				}
			default:
				print("Unexpected mocked status code: \(responseJSON)")
				completion(nil, MMInternalErrorType.UnknownError.foundationError)
			}
		} else {
			completion(nil, MMInternalErrorType.UnknownError.foundationError)
		}
	}
}

class DateStub: MMDate {
	let nowStub: Date
	init(nowStub: Date) {
		self.nowStub = nowStub
	}
	override var now: Date {
		return nowStub
	}
}

func timeTravel(to date: Date, block: () -> Void) {
	MobileMessaging.date = DateStub(nowStub: date)
	block()
	MobileMessaging.date = MMDate()
}

extension RequestData {
	var pushRegistrationIdHeader: String? {
		return headers?[Consts.APIHeaders.pushRegistrationId]
	}
}

var darthVaderDateOfDeath: NSDate {
	let comps = NSDateComponents()
	comps.year = 1983
	comps.month = 5
	comps.day = 25
	comps.hour = 0
	comps.minute = 0
	comps.second = 0
	comps.timeZone = TimeZone(secondsFromGMT: 0) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date! as NSDate
}

var darthVaderDateOfBirth: Date {
	let comps = NSDateComponents()
	comps.year = 1980
	comps.month = 12
	comps.day = 12
	comps.hour = 0
	comps.minute = 0
	comps.second = 0
	comps.timeZone = TimeZone(secondsFromGMT: 0) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date!
}

class MessagHandlerMock: MMMessageHandler {
	var setSeenWasCalled: (() -> Void)?
	var sendMessageWasCalled: (([MOMessage]) -> Void)?

	override var isRunning: Bool {
		get {
			return true
		}
		set {

		}
	}

	convenience init(originalHandler: MMMessageHandler) {
		self.init(storage: originalHandler.storage, mmContext: originalHandler.mmContext)
	}

	override func syncSeenStatusUpdates(_ completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		completion?(SeenStatusSendingResult.Cancel)
	}

	override func setSeen(_ messageIds: [String], immediately: Bool, completion: @escaping (() -> Void)) {
		setSeenWasCalled?()
		completion()
	}

	override func sendMessages(_ messages: [MOMessage], isUserInitiated: Bool, completion: (([MOMessage]?, NSError?) -> Void)?) {
		sendMessageWasCalled?(messages)
		completion?(messages, nil)
	}

	override func syncMessages(handlingIteration: Int, finishBlock: ((MessagesSyncResult) -> Void)? = nil) {
		finishBlock?(MessagesSyncResult.Cancel)
	}
}

let retryableError = NSError(domain: NSURLErrorDomain, code: 404, userInfo: nil)

func performAfterDelay(_ delay: Int, work: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(delay), execute: { work() })
}
