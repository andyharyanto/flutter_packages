import Flutter
import Photos
import FBSDKCoreKit
import FBSDKShareKit
import UniformTypeIdentifiers
import UIKit

public class ShareUtil {

    public let SUCCESS: String = "SUCCESS"
    public let ERROR_APP_NOT_AVAILABLE: String = "ERROR_APP_NOT_AVAILABLE"
    public let ERROR_FEATURE_NOT_AVAILABLE_FOR_THIS_VERSON: String =
        "ERROR_FEATURE_NOT_AVAILABLE_FOR_THIS_VERSON"
    public let ERROR: String = "ERROR"
    public let NOT_IMPLEMENTED: String = "NOT_IMPLEMENTED"

    let argAttributionURL: String = "attributionURL"
    let argImagePaths: String = "imagePaths"
    let argImagePath: String = "imagePath"
    let argbackgroundImage: String = "backgroundImage"
    let argMessage: String = "message"
    let argTitle: String = "title"
    let argstickerImage: String = "stickerImage"
    let argAppId: String = "appId"
    let argBackgroundTopColor: String = "backgroundTopColor"
    let argBackgroundBottomColor: String = "backgroundBottomColor"
    let argImages: String = "images"
    let argVideoFile: String = "videoFile"

    // Keep a strong reference.
    // Otherwise UIDocumentInteractionController can be deallocated
    // immediately after presentOpenInMenu().
    private var documentInteractionController: UIDocumentInteractionController?

    // MARK: - Installed Apps

    public func getInstalledApps(result: @escaping FlutterResult) {
        let apps = [
            ["instagram", "instagram"],
            ["facebook-stories", "facebook_stories"],
            ["whatsapp", "whatsapp"],
            ["tg", "telegram"],
            ["fb-messenger", "messenger"],
            ["tiktok", "snssdk1233"],
            ["instagram-stories", "instagram_stories"],
            ["twitter", "twitter"],
            ["sms", "message"]
        ]

        var output: [String: Bool] = [:]

        for app in apps {
            guard
                let scheme = app.first,
                let outputKey = app.last,
                let url = URL(string: "\(scheme)://")
            else {
                continue
            }

            let canOpen = UIApplication.shared.canOpenURL(url)

            if scheme == "facebook-stories" {
                output["facebook"] = canOpen
            }

            output[outputKey] = canOpen
        }

        result(output)
    }

    public func canOpenUrl(appName: String) -> Bool {
        guard let url = URL(string: "\(appName)://") else {
            return false
        }

        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - Instagram Feed

    public func shareToInstagramFeed(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let filePath = args[argImagePath] as? String,
              !filePath.isEmpty else {
            result(self.ERROR)
            return
        }

        if isImage(filePath: filePath) {
            shareImageToInstagramFeed(
                args: args,
                result: result
            )
        } else {
            shareVideoToInstagramFeed(
                args: args,
                result: result
            )
        }
    }

    func isImage(filePath: String) -> Bool {
        let url = URL(fileURLWithPath: filePath)

        guard
            let type = UTType(filenameExtension: url.pathExtension)
        else {
            return false
        }

        return type.conforms(to: .image)
    }

    // MARK: Instagram Video Feed

    func shareVideoToInstagramFeed(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let videoFile = args[argImagePath] as? String,
              !videoFile.isEmpty else {
            result(self.ERROR)
            return
        }

        let videoURL = URL(fileURLWithPath: videoFile)

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            result(self.ERROR)
            return
        }

        guard let videoData = try? Data(contentsOf: videoURL) else {
            result(self.ERROR)
            return
        }

        getLibraryPermissionIfNecessary { granted in
            guard granted else {
                result(self.ERROR)
                return
            }

            PHPhotoLibrary.shared().performChanges({

                let documentsPath =
                    NSSearchPathForDirectoriesInDomains(
                        .documentDirectory,
                        .userDomainMask,
                        true
                    )[0]

                let filePath =
                    "\(documentsPath)/\(UUID().uuidString).mp4"

                do {
                    try videoData.write(
                        to: URL(fileURLWithPath: filePath),
                        options: .atomic
                    )

                    PHAssetChangeRequest.creationRequestForAssetFromVideo(
                        atFileURL: URL(fileURLWithPath: filePath)
                    )
                } catch {
                    print(
                        "Failed to save Instagram video: \(error.localizedDescription)"
                    )
                }

            }, completionHandler: { success, error in

                if let error = error {
                    print(
                        "Instagram video save error: \(error.localizedDescription)"
                    )
                }

                guard success else {
                    result(self.ERROR)
                    return
                }

                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [
                    NSSortDescriptor(
                        key: "creationDate",
                        ascending: false
                    )
                ]

                let fetchResult = PHAsset.fetchAssets(
                    with: .video,
                    options: fetchOptions
                )

                guard let lastAsset = fetchResult.firstObject else {
                    result(self.ERROR)
                    return
                }

                let localIdentifier = lastAsset.localIdentifier

                guard
                    let url = URL(
                        string: "instagram://library?LocalIdentifier=\(localIdentifier)"
                    )
                else {
                    result(self.ERROR_APP_NOT_AVAILABLE)
                    return
                }

                DispatchQueue.main.async {

                    guard UIApplication.shared.canOpenURL(url) else {
                        result(self.ERROR_APP_NOT_AVAILABLE)
                        return
                    }

                    UIApplication.shared.open(
                        url,
                        options: [:]
                    ) { opened in

                        result(
                            opened
                                ? self.SUCCESS
                                : self.ERROR
                        )
                    }
                }
            })
        }
    }

    // MARK: Instagram Image Feed

    func shareImageToInstagramFeed(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let imageFile = args[argImagePath] as? String,
              !imageFile.isEmpty else {
            result(self.ERROR)
            return
        }

        let imageURL = URL(fileURLWithPath: imageFile)

        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            result(self.ERROR)
            return
        }

        guard let imageData = try? Data(contentsOf: imageURL) else {
            result(self.ERROR)
            return
        }

        getLibraryPermissionIfNecessary { granted in
            guard granted else {
                result(self.ERROR)
                return
            }

            PHPhotoLibrary.shared().performChanges({

                let documentsPath =
                    NSSearchPathForDirectoriesInDomains(
                        .documentDirectory,
                        .userDomainMask,
                        true
                    )[0]

                let filePath =
                    "\(documentsPath)/\(UUID().uuidString).jpeg"

                do {
                    try imageData.write(
                        to: URL(fileURLWithPath: filePath),
                        options: .atomic
                    )

                    PHAssetChangeRequest.creationRequestForAssetFromImage(
                        atFileURL: URL(fileURLWithPath: filePath)
                    )
                } catch {
                    print(
                        "Failed to save Instagram image: \(error.localizedDescription)"
                    )
                }

            }, completionHandler: { success, error in

                if let error = error {
                    print(
                        "Instagram image save error: \(error.localizedDescription)"
                    )
                }

                guard success else {
                    result(self.ERROR)
                    return
                }

                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [
                    NSSortDescriptor(
                        key: "creationDate",
                        ascending: false
                    )
                ]

                let fetchResult = PHAsset.fetchAssets(
                    with: .image,
                    options: fetchOptions
                )

                guard let lastAsset = fetchResult.firstObject else {
                    result(self.ERROR)
                    return
                }

                let localIdentifier = lastAsset.localIdentifier

                guard
                    let url = URL(
                        string: "instagram://library?LocalIdentifier=\(localIdentifier)"
                    )
                else {
                    result(self.ERROR_APP_NOT_AVAILABLE)
                    return
                }

                DispatchQueue.main.async {

                    guard UIApplication.shared.canOpenURL(url) else {
                        result(self.ERROR_APP_NOT_AVAILABLE)
                        return
                    }

                    UIApplication.shared.open(
                        url,
                        options: [:]
                    ) { opened in

                        result(
                            opened
                                ? self.SUCCESS
                                : self.ERROR
                        )
                    }
                }
            })
        }
    }

    // MARK: - Photo Library Permission

    func getLibraryPermissionIfNecessary(
        completionHandler: @escaping (Bool) -> Void
    ) {
        let status = PHPhotoLibrary.authorizationStatus(
            for: .addOnly
        )

        switch status {

        case .authorized, .limited:
            completionHandler(true)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(
                for: .addOnly
            ) { status in

                DispatchQueue.main.async {
                    completionHandler(
                        status == .authorized ||
                        status == .limited
                    )
                }
            }

        default:
            completionHandler(false)
        }
    }

    // MARK: - System Share

    public func shareToSystem(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        let text = args[argMessage] as? String
        let filePaths = args[argImagePaths] as? [String]

        var data: [Any] = []

        if let text = text {
            data.append(text)
        }

        if let filePaths = filePaths {
            for filePath in filePaths {

                guard
                    FileManager.default.fileExists(atPath: filePath)
                else {
                    continue
                }

                data.append(
                    URL(fileURLWithPath: filePath)
                )
            }
        }

        guard !data.isEmpty else {
            result(self.ERROR)
            return
        }

        DispatchQueue.main.async {

            guard let viewController =
                UIApplication.topViewController()
            else {
                result(self.ERROR)
                return
            }

            let activityViewController =
                UIActivityViewController(
                    activityItems: data,
                    applicationActivities: nil
                )

            viewController.present(
                activityViewController,
                animated: true
            )

            result(self.SUCCESS)
        }
    }

    // MARK: - Clipboard

    func copyToClipboard(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let message = args[self.argMessage] as? String else {
            result(self.ERROR)
            return
        }

        UIPasteboard.general.string = message

        result(self.SUCCESS)
    }

    // MARK: - WhatsApp Text

    func shareToWhatsApp(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let message = args[self.argMessage] as? String else {
            result(self.ERROR)
            return
        }

        var components = URLComponents()
        components.scheme = "whatsapp"
        components.host = "send"
        components.queryItems = [
            URLQueryItem(
                name: "text",
                value: message
            )
        ]

        guard let whatsappURL = components.url else {
            result(self.ERROR)
            return
        }

        guard UIApplication.shared.canOpenURL(whatsappURL) else {
            result(self.ERROR_APP_NOT_AVAILABLE)
            return
        }

        DispatchQueue.main.async {

            UIApplication.shared.open(
                whatsappURL,
                options: [:]
            ) { success in

                result(
                    success
                        ? self.SUCCESS
                        : self.ERROR
                )
            }
        }
    }

    // MARK: - Facebook Post

    func shareToFacebookPost(
        args: [String: Any?],
        result: @escaping FlutterResult,
        delegate: SharingDelegate
    ) {
        guard let message = args[self.argMessage] as? String else {
            result(self.ERROR)
            return
        }

        guard let imagePaths =
            args[self.argImagePaths] as? [String]
        else {
            result(self.ERROR)
            return
        }

        let content = SharePhotoContent()
        var photos: [SharePhoto] = []

        for imagePath in imagePaths {

            guard
                let image = UIImage(
                    contentsOfFile: imagePath
                )
            else {
                continue
            }

            let photo = SharePhoto(
                image: image,
                isUserGenerated: true
            )

            photos.append(photo)
        }

        guard !photos.isEmpty else {
            result(self.ERROR)
            return
        }

        content.photos = photos
        content.hashtag = Hashtag(message)

        guard let viewController =
            UIApplication.topViewController()
        else {
            result(self.ERROR)
            return
        }

        let dialog = ShareDialog(
            viewController: viewController,
            content: content,
            delegate: delegate
        )

        do {
            try dialog.validate()
        } catch {
            result(self.ERROR)
            return
        }

        dialog.show()

        result(self.SUCCESS)
    }

    // MARK: - Telegram

    func shareToTelegram(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let message = args[self.argMessage] as? String else {
            result(self.ERROR)
            return
        }

        guard
            let telegramURL = URL(
                string: "tg://msg?text=\(message)"
            )
        else {
            result(self.ERROR)
            return
        }

        guard UIApplication.shared.canOpenURL(telegramURL) else {
            result(self.ERROR_APP_NOT_AVAILABLE)
            return
        }

        DispatchQueue.main.async {

            UIApplication.shared.open(
                telegramURL,
                options: [:]
            ) { success in

                result(
                    success
                        ? self.SUCCESS
                        : self.ERROR
                )
            }
        }
    }

    // MARK: - Instagram Direct

    public func shareToInstagramDirect(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        if #available(iOS 10.0, *) {

            guard let message =
                args[self.argMessage] as? String
            else {
                result(self.ERROR)
                return
            }

            guard canOpenUrl(appName: "instagram") else {
                result(self.ERROR_APP_NOT_AVAILABLE)
                return
            }

            var components = URLComponents()
            components.scheme = "instagram"
            components.host = "sharesheet"
            components.queryItems = [
                URLQueryItem(
                    name: "text",
                    value: message
                )
            ]

            guard let url = components.url else {
                result(self.ERROR)
                return
            }

            DispatchQueue.main.async {

                UIApplication.shared.open(
                    url,
                    options: [:]
                ) { success in

                    result(
                        success
                            ? self.SUCCESS
                            : self.ERROR
                    )
                }
            }

        } else {
            result(
                self.ERROR_FEATURE_NOT_AVAILABLE_FOR_THIS_VERSON
            )
        }
    }

    // MARK: - Messenger

    public func shareToMessenger(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        if #available(iOS 10.0, *) {

            guard let message =
                args[self.argMessage] as? String
            else {
                result(self.ERROR)
                return
            }

            guard canOpenUrl(appName: "fb-messenger") else {
                result(self.ERROR_APP_NOT_AVAILABLE)
                return
            }

            var components = URLComponents()
            components.scheme = "fb-messenger"
            components.host = "share"
            components.queryItems = [
                URLQueryItem(
                    name: "link",
                    value: message
                )
            ]

            guard let url = components.url else {
                result(self.ERROR)
                return
            }

            DispatchQueue.main.async {

                UIApplication.shared.open(
                    url,
                    options: [:]
                ) { success in

                    result(
                        success
                            ? self.SUCCESS
                            : self.ERROR
                    )
                }
            }

        } else {
            result(
                self.ERROR_FEATURE_NOT_AVAILABLE_FOR_THIS_VERSON
            )
        }
    }

    // MARK: - SMS

    public func shareToSms(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let message =
            args[self.argMessage] as? String
        else {
            result(self.ERROR)
            return
        }

        if #available(iOS 10.0, *) {

            guard canOpenUrl(appName: "sms") else {
                result(self.ERROR_APP_NOT_AVAILABLE)
                return
            }

            var components = URLComponents()
            components.scheme = "sms"
            components.queryItems = [
                URLQueryItem(
                    name: "body",
                    value: message
                )
            ]

            guard let url = components.url else {
                result(self.ERROR)
                return
            }

            DispatchQueue.main.async {

                UIApplication.shared.open(
                    url,
                    options: [:]
                ) { success in

                    result(
                        success
                            ? self.SUCCESS
                            : self.ERROR
                    )
                }
            }

        } else {
            result(
                self.ERROR_FEATURE_NOT_AVAILABLE_FOR_THIS_VERSON
            )
        }
    }

    // MARK: - Facebook Story

    public func shareToFacebookStory(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let appId =
            args[self.argAppId] as? String,
            !appId.isEmpty
        else {
            result(self.ERROR)
            return
        }

        let imagePath =
            args[self.argbackgroundImage] as? String

        let videoFile =
            args[self.argVideoFile] as? String

        let stickerPath =
            args[self.argstickerImage] as? String

        let backgroundTopColor =
            args[self.argBackgroundTopColor] as? String

        let backgroundBottomColor =
            args[self.argBackgroundBottomColor] as? String

        let attributionURL =
            args[self.argAttributionURL] as? String

        guard
            let facebookURL =
                URL(string: "facebook-stories://share")
        else {
            result(self.ERROR_APP_NOT_AVAILABLE)
            return
        }

        guard UIApplication.shared.canOpenURL(
            facebookURL
        ) else {
            result(self.ERROR_APP_NOT_AVAILABLE)
            return
        }

        var pasteboardItem: [String: Any] = [:]

        // App ID
        pasteboardItem[
            "com.facebook.sharedSticker.appID"
        ] = appId

        // Attribution URL
        if let attributionURL = attributionURL,
           !attributionURL.isEmpty {

            pasteboardItem[
                "com.facebook.sharedSticker.attributionURL"
            ] = attributionURL
        }

        // Background top color
        if let backgroundTopColor = backgroundTopColor,
           !backgroundTopColor.isEmpty {

            pasteboardItem[
                "com.facebook.sharedSticker.backgroundTopColor"
            ] = backgroundTopColor
        }

        // Background bottom color
        if let backgroundBottomColor = backgroundBottomColor,
           !backgroundBottomColor.isEmpty {

            pasteboardItem[
                "com.facebook.sharedSticker.backgroundBottomColor"
            ] = backgroundBottomColor
        }

        // Background image
        if let imagePath = imagePath,
           !imagePath.isEmpty,
           let image = UIImage(
               contentsOfFile: imagePath
           ) {

            pasteboardItem[
                "com.facebook.sharedSticker.backgroundImage"
            ] = image
        }

        // Sticker image
        if let stickerPath = stickerPath,
           !stickerPath.isEmpty,
           let sticker = UIImage(
               contentsOfFile: stickerPath
           ) {

            pasteboardItem[
                "com.facebook.sharedSticker.stickerImage"
            ] = sticker
        }

        // Background video
        if let videoFile = videoFile,
           !videoFile.isEmpty {

            let videoURL =
                URL(fileURLWithPath: videoFile)

            if let videoData =
                try? Data(contentsOf: videoURL) {

                pasteboardItem[
                    "com.facebook.sharedSticker.backgroundVideo"
                ] = videoData
            }
        }

        guard !pasteboardItem.isEmpty else {
            result(self.ERROR)
            return
        }

        let pasteboardOptions:
            [UIPasteboard.OptionsKey: Any] = [
                .expirationDate:
                    Date().addingTimeInterval(60 * 5)
            ]

        UIPasteboard.general.setItems(
            [pasteboardItem],
            options: pasteboardOptions
        )

        DispatchQueue.main.async {

            UIApplication.shared.open(
                facebookURL,
                options: [:]
            ) { success in

                result(
                    success
                        ? self.SUCCESS
                        : self.ERROR
                )
            }
        }
    }

    // MARK: - Twitter / X

    func shareToTwitter(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let message =
            args[self.argMessage] as? String
        else {
            result(self.ERROR)
            return
        }

        /*
         IMPORTANT:
         SLComposeViewController / Social.framework
         is deprecated and should not be used on modern iOS.

         For text-only sharing, use the Twitter/X intent.
        */

        var components = URLComponents()
        components.scheme = "twitter"
        components.host = "intent"
        components.path = "/tweet"
        components.queryItems = [
            URLQueryItem(
                name: "text",
                value: message
            )
        ]

        guard let twitterURL = components.url else {
            result(self.ERROR)
            return
        }

        guard UIApplication.shared.canOpenURL(
            twitterURL
        ) else {
            result(self.ERROR_APP_NOT_AVAILABLE)
            return
        }

        DispatchQueue.main.async {

            UIApplication.shared.open(
                twitterURL,
                options: [:]
            ) { success in

                result(
                    success
                        ? self.SUCCESS
                        : self.ERROR
                )
            }
        }
    }

    // MARK: - Instagram Story

    func shareToInstagramStory(
        args: [String: Any?],
        result: @escaping FlutterResult
    ) {
        guard let appId =
            args[self.argAppId] as? String,
            !appId.isEmpty
        else {
            result(self.ERROR)
            return
        }

        let imagePath =
            args[self.argbackgroundImage] as? String

        let videoFile =
            args[self.argVideoFile] as? String

        let stickerPath =
            args[self.argstickerImage] as? String

        let backgroundTopColor =
            args[self.argBackgroundTopColor] as? String

        let backgroundBottomColor =
            args[self.argBackgroundBottomColor] as? String

        let attributionURL =
            args[self.argAttributionURL] as? String

        guard
            let instagramURL = URL(
                string:
                    "instagram-stories://share?source_application=\(appId)"
            )
        else {
            result(self.ERROR_APP_NOT_AVAILABLE)
            return
        }

        guard UIApplication.shared.canOpenURL(
            instagramURL
        ) else {
            result(self.ERROR_APP_NOT_AVAILABLE)
            return
        }

        var pasteboardItem: [String: Any] = [:]

        // Attribution URL
        if let attributionURL = attributionURL,
           !attributionURL.isEmpty {

            pasteboardItem[
                "com.instagram.sharedSticker.attributionURL"
            ] = attributionURL
        }

        // Background image
        if let imagePath = imagePath,
           !imagePath.isEmpty,
           let backgroundImage = UIImage(
               contentsOfFile: imagePath
           ) {

            pasteboardItem[
                "com.instagram.sharedSticker.backgroundImage"
            ] = backgroundImage
        }

        // Sticker image
        if let stickerPath = stickerPath,
           !stickerPath.isEmpty,
           let stickerImage = UIImage(
               contentsOfFile: stickerPath
           ) {

            pasteboardItem[
                "com.instagram.sharedSticker.stickerImage"
            ] = stickerImage
        }

        // Background video
        if let videoFile = videoFile,
           !videoFile.isEmpty {

            let backgroundVideoURL =
                URL(fileURLWithPath: videoFile)

            if let videoData =
                try? Data(contentsOf: backgroundVideoURL) {

                pasteboardItem[
                    "com.instagram.sharedSticker.backgroundVideo"
                ] = videoData
            }
        }

        // Background top color
        if let backgroundTopColor = backgroundTopColor,
           !backgroundTopColor.isEmpty {

            pasteboardItem[
                "com.instagram.sharedSticker.backgroundTopColor"
            ] = backgroundTopColor
        }

        // Background bottom color
        if let backgroundBottomColor = backgroundBottomColor,
           !backgroundBottomColor.isEmpty {

            pasteboardItem[
                "com.instagram.sharedSticker.backgroundBottomColor"
            ] = backgroundBottomColor
        }

        guard !pasteboardItem.isEmpty else {
            result(self.ERROR)
            return
        }

        let pasteboardOptions:
            [UIPasteboard.OptionsKey: Any] = [
                .expirationDate:
                    Date().addingTimeInterval(60 * 5)
            ]

        UIPasteboard.general.setItems(
            [pasteboardItem],
            options: pasteboardOptions
        )

        DispatchQueue.main.async {

            UIApplication.shared.open(
                instagramURL,
                options: [:]
            ) { success in

                result(
                    success
                        ? self.SUCCESS
                        : self.ERROR
                )
            }
        }
    }

    // MARK: - WhatsApp Image

    public func shareImageToWhatsApp(
        args: [String: Any?],
        result: @escaping FlutterResult,
        delegate: SharingDelegate
    ) {
        guard let imagePath =
            args[self.argImagePath] as? String,
            !imagePath.isEmpty
        else {
            result(
                FlutterError(
                    code: "INVALID_PATH",
                    message: "The image path is invalid",
                    details: nil
                )
            )
            return
        }

        guard
            FileManager.default.fileExists(
                atPath: imagePath
            )
        else {
            result(
                FlutterError(
                    code: "FILE_NOT_FOUND",
                    message: "The image file does not exist",
                    details: nil
                )
            )
            return
        }

        guard let image =
            UIImage(contentsOfFile: imagePath)
        else {
            result(
                FlutterError(
                    code: "IMAGE_ERROR",
                    message: "Could not load image",
                    details: nil
                )
            )
            return
        }

        guard
            let imageData =
                image.jpegData(compressionQuality: 1.0)
        else {
            result(
                FlutterError(
                    code: "IMAGE_DATA_ERROR",
                    message: "Could not convert image to JPEG",
                    details: nil
                )
            )
            return
        }

        guard canOpenUrl(appName: "whatsapp") else {
            result(self.ERROR_APP_NOT_AVAILABLE)
            return
        }

        let documentsDirectory =
            FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!

        let tempFile =
            documentsDirectory
                .appendingPathComponent(
                    "whatsAppTmp-\(UUID().uuidString).jpg"
                )

        do {

            try imageData.write(
                to: tempFile,
                options: .atomic
            )

        } catch {

            result(
                FlutterError(
                    code: "WRITE_ERROR",
                    message:
                        "Could not write temporary WhatsApp image",
                    details:
                        error.localizedDescription
                )
            )

            return
        }

        DispatchQueue.main.async {

            guard
                let viewController =
                    UIApplication.topViewController()
            else {
                result(self.ERROR)
                return
            }

            self.documentInteractionController =
                UIDocumentInteractionController(
                    url: tempFile
                )

            self.documentInteractionController?.uti =
                "net.whatsapp.image"

            let presented =
                self.documentInteractionController?.presentOpenInMenu(
                    from: viewController.view.bounds,
                    in: viewController.view,
                    animated: true
                ) ?? false

            result(
                presented
                    ? self.SUCCESS
                    : self.ERROR
            )
        }
    }
}

// MARK: - UIApplication

extension UIApplication {

    class func topViewController(
        controller: UIViewController? = nil
    ) -> UIViewController? {

        let rootController: UIViewController?

        if let controller = controller {
            rootController = controller
        } else {
            rootController = UIApplication.shared
                .connectedScenes
                .compactMap {
                    $0 as? UIWindowScene
                }
                .flatMap {
                    $0.windows
                }
                .first {
                    $0.isKeyWindow
                }?
                .rootViewController
        }

        guard let controller = rootController else {
            return nil
        }

        if let navigationController =
            controller as? UINavigationController {

            return topViewController(
                controller:
                    navigationController.visibleViewController
            )
        }

        if let tabController =
            controller as? UITabBarController {

            if let selected =
                tabController.selectedViewController {

                return topViewController(
                    controller: selected
                )
            }
        }

        if let presented =
            controller.presentedViewController {

            return topViewController(
                controller: presented
            )
        }

        return controller
    }
}

// MARK: - Transparent View Controller

class TransparentViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.clear
        view.isOpaque = false
    }
}
