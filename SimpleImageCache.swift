import Foundation

class SimpleCache: NSObject, NSURLSessionTaskDelegate {
	
	class var sharedInstance: SimpleCache {
		struct Singleton {
			static let instance = SimpleCache()
		}
		return Singleton.instance
	}
	
	var session:NSURLSession!
	var URLCache = NSURLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "ImageDownloadCache")
	var downloadQueue = Dictionary<NSURL, (UIImage?, NSError?)->()?>()
	
	override init() {
		super.init()
		
		var config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.requestCachePolicy = NSURLRequestCachePolicy.ReturnCacheDataElseLoad
		config.URLCache = URLCache
		
		self.session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
	}
	
	func getImageFromCache(url:NSURL, completion:(UIImage?, NSError?)->()) {
		let urlRequest = NSURLRequest(URL: url, cachePolicy: NSURLRequestCachePolicy.ReturnCacheDataElseLoad, timeoutInterval: 30.0)
		if let response = URLCache.cachedResponseForRequest(urlRequest)? {
			var image = UIImage(data: response.data)
			dispatch_async(dispatch_get_main_queue()) { () -> Void in
				completion(image, nil)
				return
			}
		} else {
			completion(nil, nil)
		}
	}
	
	func getImage(url:NSURL, completion:((UIImage?, NSError?)->())?) {
		
		let urlRequest = NSURLRequest(URL: url, cachePolicy: NSURLRequestCachePolicy.ReturnCacheDataElseLoad, timeoutInterval: 30.0)

		if let response = URLCache.cachedResponseForRequest(urlRequest)? {
			var image = UIImage(data: response.data)
			dispatch_async(dispatch_get_main_queue()) { () -> Void in
				completion?(image, nil)
				return
			}
		} else {
			let task = self.session.dataTaskWithRequest(urlRequest) { [weak self] (data, response, error) -> Void in
				if let strongSelf = self {
					if let completionHandler = strongSelf.downloadQueue[url] {
						if let errorReceived = error {
//							println("ERROR >>>>>>>>> \(errorReceived.localizedFailureReason)")
							Utils.mainQueue() {
								completionHandler(nil, nil)
								return
							}
						} else {
							if let httpResponse = response as? NSHTTPURLResponse {
								if httpResponse.statusCode >= 400 {
									completionHandler(nil, NSError(domain: NSURLErrorDomain, code: httpResponse.statusCode, userInfo: nil))
								} else {
//									println(" >>>>>>>>> LENGTHS: \(response.expectedContentLength) - got: \(data.length)")
									strongSelf.URLCache.storeCachedResponse(NSCachedURLResponse(response:response, data:data, userInfo:nil, storagePolicy:NSURLCacheStoragePolicy.Allowed), forRequest: urlRequest)
								
									var image = UIImage(data: data)
									Utils.mainQueue() {
										completionHandler(image, nil)
										return
									}
								}
							}
						}
					}
					strongSelf.cancelImage(url)
				}
			}
			addToQueue(url, task, completion)
		}
	}
	
	func cancelImage(requestUrl:NSURL?) {
		if let url = requestUrl {
			if let index = self.downloadQueue.indexForKey(url) {
				self.downloadQueue.removeAtIndex(index)
			}
		}
	}
	
	
	// MARK: - Private
	
	private func addToQueue(url:NSURL, _ task:NSURLSessionDataTask, completion:((UIImage?, NSError?)->())?) {
		self.downloadQueue[url] = completion
		if task.state != .Running {
			task.resume()
		}
	}
}