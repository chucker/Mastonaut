import Foundation
import CoreTootin

private var avatarImageCache = [UUID:NSImage]()
private var resourcesFetcher = ResourcesFetcher(urlSession: AppDelegate.shared.resourcesUrlSession)

extension AuthorizedAccount {
	var avatarImage: NSImage {
		let placeholderImg = #imageLiteral(resourceName: "missing")

		if let avatarImage = avatarImageCache[uuid] {
			avatarImage.size = NSSize(width: 16, height: 16)
			return avatarImage
		} else if let avatarURL = avatarURL {
			fetchImageOrFallback(url: avatarURL) { [weak self] image in
				DispatchQueue.main.async {
					guard let strongSelf = self else { return }
					image.size = NSSize(width: 16, height: 16)
					avatarImageCache[strongSelf.uuid] = image
				}
			}
		} else {
			placeholderImg.size = NSSize(width: 16, height: 16)
			avatarImageCache[uuid] = placeholderImg
		}
		
		return placeholderImg
	}
	
	private func fetchImageOrFallback(url: URL, completion: @escaping (NSImage) -> Void)
	{
		resourcesFetcher.fetchImage(with: url) { (result) in
			if case .success(let image) = result
			{
				completion(image)
			}
			else
			{
				completion(#imageLiteral(resourceName: "missing"))
			}
		}
	}
}
