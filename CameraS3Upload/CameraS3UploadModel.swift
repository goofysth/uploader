//
//  File.swift
//  CameraS3Upload
//
//  Created by Dragan Basta on 1/26/17.
//  Copyright © 2017 Dragan Basta. All rights reserved.
//

import Foundation
import AWSS3
import AWSCore

class CameraS3UploadModel {
    
    enum ConnectionParameters {
        static let secretKey = "dhIKReosMLKuGO100zg7QuNSXMlMm05zkCjuXiQ/"
        static let accessKey = "AKIAJQKVM4OBK6CZKNUQ"
        static let S3BucketName = "im-devtest"
    }
    
    var imagesToUploadQueue = [UIImage?]()
    
    //MARK: Uploading images methods
    @objc func uploadPhotos() {
        
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: ConnectionParameters.accessKey, secretKey: ConnectionParameters.secretKey)
        let configuration = AWSServiceConfiguration(region:AWSRegionType.usEast1, credentialsProvider:credentialsProvider)
        
        var uploadFailed = false
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        while (imagesToUploadQueue.isEmpty != true && NetworkUtilClass.isInternetAvailable()) {
            
            let image = imagesToUploadQueue.remove(at:0)
        
            //Generating random string name for each Image
            //Didn't work on grouping images by names(for example name can contain exposure value and number of picture taken)
            let remoteName = Utilities.randomString(length: 10) + ".jpg"
            let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(remoteName)
            
            let data = UIImageJPEGRepresentation(image!, 1.0)
            do {
                try data?.write(to: fileURL)
            }
            catch {}
            
            let uploadRequest = AWSS3TransferManagerUploadRequest()!
            uploadRequest.body = fileURL
            uploadRequest.key = remoteName
            uploadRequest.bucket = ConnectionParameters.S3BucketName
            uploadRequest.contentType = "image/jpeg"
            uploadRequest.acl = .publicRead
            
            let transferManager = AWSS3TransferManager.default()
            transferManager?.upload(uploadRequest).continue({ (task: AWSTask<AnyObject>) -> Any? in
                
                if let error = task.error {
                    print("Upload fail error: (\(error))")
                    uploadFailed = true
                }
                if let exception = task.exception {
                    print("Upload fail exception: (\(exception))")
                    uploadFailed = false
                }
                
                if task.result != nil {
                    let url = AWSS3.default().configuration.endpoint.url
                    let publicURL = url?.appendingPathComponent(uploadRequest.bucket!).appendingPathComponent(uploadRequest.key!)
                    print("Successfully uploaded to:\(publicURL)")
                }
                
                //If upload failed, put the element back to the queue so it can try upload again later(example: when connection is available)
                if uploadFailed == true {
                    let image = UIImage(contentsOfFile: uploadRequest.body.path)
                    self.imagesToUploadQueue.append(image)
                }
                
                return nil
            })
        }
        
    }
}
