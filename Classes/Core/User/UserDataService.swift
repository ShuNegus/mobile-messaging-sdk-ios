//
// Created by Andrey Kadochnikov on 31/10/2018.
//

import Foundation

final class UserDataService: MobileMessagingService {
	init(mmContext: MobileMessaging) {
		super.init(mmContext: mmContext, id: "UserDataService")
	}

	func setInstallation(withPushRegistrationId pushRegId: String, asPrimary primary: Bool, completion: @escaping ([Installation]?, NSError?) -> Void) {
		let finish: (NSError?) -> Void = { (error) in
			if error == nil {
				let ins = self.resolveInstallationsAfterPrimaryChange(pushRegId, primary)
				User.modifyAll(with: { user in
					user.installations = ins
				})
			}
			completion(self.mmContext.resolveUser().installations, error)
		}

		if mmContext.currentInstallation().pushRegistrationId == pushRegId {
			let ci = mmContext.currentInstallation()
			ci.isPrimaryDevice = primary
			mmContext.installationService.save(installationData: ci, completion: finish)
		} else {
			guard let authPushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
				MMLogError("[OtherInstallation] There is no registration. Finishing...")
				completion(self.mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.NoRegistration))
				return
			}
			let body = ["isPrimary": primary]
			if let request = PatchInstance(applicationCode: mmContext.applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: pushRegId, body: body, returnPushServiceToken: false) {
				MobileMessaging.httpSessionManager.sendRequest(request, completion: { finish($0.error) })
			} else {
				completion(mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.UnknownError))
			}
		}
	}

	func depersonalizeInstallation(withPushRegistrationId pushRegId: String, completion: @escaping ([Installation]?, NSError?) -> Void) {
		guard pushRegId != mmContext.currentInstallation().pushRegistrationId else {
			MMLogError("[OtherInstallation] Attempt to depersonalize current installation with inappropriate API. Aborting...")
			completion(mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.CantLogoutCurrentRegistration))
			return
		}
		guard let authPushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			MMLogError("[OtherInstallation] There is no registration. Finishing...")
			completion(mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.NoRegistration))
			return
		}

		let request = PostDepersonalize(applicationCode: mmContext.applicationCode, pushRegistrationId: authPushRegistrationId, pushRegistrationIdToDepersonalize: pushRegId)
		MobileMessaging.httpSessionManager.sendRequest(request) { result in
			if result.error == nil {
				let ins = self.resolveInstallationsAfterLogout(pushRegId)
				User.modifyAll(with: { (user) in
					user.installations = ins
				})
			}
			completion(self.mmContext.resolveUser().installations, result.error)
		}
	}

	func save(userData: User, completion: @escaping (NSError?) -> Void) {
		MMLogDebug("[UserDataService] saving \(userData.dictionaryRepresentation)")
		userData.archiveDirty()
		syncWithServer(completion)
	}

	var isChanged: Bool {
		return !User.delta.isEmpty
	}

	func resolveInstallationsAfterPrimaryChange(_ pushRegId: String, _ isPrimary: Bool) -> [Installation]? {
		let ret = mmContext.resolveUser().installations
		if let idx = ret?.firstIndex(where: { $0.isPrimaryDevice == true }) {
			ret?[idx].isPrimaryDevice = false
		}
		if let idx = ret?.firstIndex(where: { $0.pushRegistrationId == pushRegId }) {
			ret?[idx].isPrimaryDevice = isPrimary
		}
		return ret
	}

	func resolveInstallationsAfterLogout(_ pushRegId: String) -> [Installation]? {
		var ret = mmContext.resolveUser().installations
		if let idx = ret?.firstIndex(where: { $0.pushRegistrationId == pushRegId }) {
			ret?.remove(at: idx)
		}
		return ret
	}

	func personalize(forceDepersonalize: Bool, userIdentity: UserIdentity, userAttributes: UserAttributes?, completion: @escaping (NSError?) -> Void) {

		let du = mmContext.dirtyUser()
		UserDataMapper.apply(userIdentity: userIdentity, to: du)
		if let userAttributes = userAttributes {
			UserDataMapper.apply(userAttributes: userAttributes, to: du)
		}
		du.archiveDirty()


		if let op = PersonalizeOperation(
			forceDepersonalize: forceDepersonalize,
			userIdentity: userIdentity,
			userAttributes: userAttributes,
			mmContext: mmContext,
			finishBlock: { completion($0.error) })
		{
			op.queuePriority = .veryHigh
			installationQueue.addOperation(op)
		} else {
			completion(nil)
		}
	}

	func fetchFromServer(completion: @escaping (User, NSError?) -> Void) {
		MMLogDebug("[UserDataService] fetch from server")
		if let op = FetchUserOperation(
			currentUser: mmContext.currentUser(),
			dirtyUser: mmContext.dirtyUser(),
			mmContext: mmContext,
			finishBlock: { completion(self.mmContext.resolveUser(), $0.error) })
		{
			installationQueue.addOperation(op)
		} else {
			completion(mmContext.resolveUser(), nil)
		}
	}

	// MARK: - MobileMessagingService protocol {
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		MMLogDebug("[UserDataService] log out")
		User.empty.archiveAll()
		completion()
	}

	override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
		MMLogDebug("[UserDataService] sync user data with server")

		if let op = UpdateUserOperation(
			currentUser: mmContext.currentUser(),
			dirtyUser: mmContext.dirtyUser(),
			mmContext: mmContext,
			requireResponse: false,
			finishBlock: { completion($0.error) })
		{
			installationQueue.addOperation(op)
		} else {
			completion(nil)
		}
	}
	// MARK: }
}
