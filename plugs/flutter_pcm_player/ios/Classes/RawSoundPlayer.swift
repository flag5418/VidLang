import Foundation
import AudioToolbox
import AVFoundation

public enum PlayState: Int {
  case Stopped = 0
  case Playing = 1
  case Paused = 2
}

public enum PCMType: Int {
  case PCMI8 = 0
  case PCMI16 = 1
  case PCMF32 = 2
}

// C-style callback function for AudioQueue output
// This is called when a buffer has finished playing.
func aqOutputCallback(
    inUserData: UnsafeMutableRawPointer?,
    inAQ: AudioQueueRef,
    inBuffer: AudioQueueBufferRef
) {
    // Free the buffer to release memory.
    // In a more complex implementation, we might recycle this buffer into a pool.
    AudioQueueFreeBuffer(inAQ, inBuffer)
}

class RawSoundPlayer {

  private var queue: AudioQueueRef?
  private var format = AudioStreamBasicDescription()
  
  private var isRunning = false
  private var isPaused = false
  private var volume: Float = 1.0
  
  private var sampleRate: Double = 16000
  private var nChannels: UInt32 = 1
  private var pcmType: PCMType = .PCMI16

  init?(sampleRate: Int, nChannels: Int, pcmType: PCMType) {
    self.sampleRate = Double(sampleRate)
    self.nChannels = UInt32(nChannels)
    self.pcmType = pcmType
    
    // Initialize the queue
    createQueue()
    NSLog("RawSoundPlayer (AudioQueue): initialized")
  }
  
  private func createQueue() {
      // 1. Setup AudioStreamBasicDescription
      format.mSampleRate = sampleRate
      format.mFormatID = kAudioFormatLinearPCM
      format.mChannelsPerFrame = nChannels
      format.mFramesPerPacket = 1
      
      switch pcmType {
      case .PCMI8:
          // 8-bit assuming signed for consistency with common usage, 
          // though WAV 8-bit is usually unsigned. 
          // Flutter PCM usually sends what is requested. 
          // Let's assume standard Linear PCM flags.
          format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
          format.mBitsPerChannel = 8
          format.mBytesPerPacket = 1 * nChannels
          format.mBytesPerFrame = 1 * nChannels
      case .PCMI16:
          // 16-bit signed integer (Little Endian on iOS usually, but CoreAudio handles native)
          format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
          format.mBitsPerChannel = 16
          format.mBytesPerPacket = 2 * nChannels
          format.mBytesPerFrame = 2 * nChannels
      case .PCMF32:
          // 32-bit float
          format.mFormatFlags = kLinearPCMFormatFlagIsFloat | kLinearPCMFormatFlagIsPacked
          format.mBitsPerChannel = 32
          format.mBytesPerPacket = 4 * nChannels
          format.mBytesPerFrame = 4 * nChannels
      }
      
      // 2. Create AudioQueue
      // We pass nil for userData as our callback is simple and stateless (just frees buffer)
      var status = AudioQueueNewOutput(
          &format,
          aqOutputCallback,
          nil,
          nil, // CFRunLoop (nil = internal thread)
          nil, // CFRunLoopMode
          0,   // Flags
          &queue
      )
      
      if status != noErr {
          NSLog("RawSoundPlayer: Error creating AudioQueue: \(status)")
          queue = nil
      } else {
          // Set initial volume
          if let q = queue {
              AudioQueueSetParameter(q, kAudioQueueParam_Volume, volume)
          }
      }
  }

  func release() -> Bool {
    return stop()
  }

  func getPlayState() -> Int {
      if isRunning {
          if isPaused { return PlayState.Paused.rawValue }
          return PlayState.Playing.rawValue
      }
      return PlayState.Stopped.rawValue
  }

  func play() -> Bool {
    guard let q = queue else {
        // Try to recreate if missing?
        createQueue()
        if queue == nil { return false }
        return play()
    }
    
    let status = AudioQueueStart(q, nil)
    if status == noErr {
        isRunning = true
        isPaused = false
        return true
    } else {
        NSLog("RawSoundPlayer: AudioQueueStart failed: \(status)")
        return false
    }
  }

  func stop() -> Bool {
    guard let q = queue else { return true }
    
    // AudioQueueStop(true) stops immediately and resets the queue (clears buffers)
    let status = AudioQueueStop(q, true)
    if status != noErr {
        NSLog("RawSoundPlayer: AudioQueueStop failed: \(status)")
    }
    
    // Dispose properly to release resources
    AudioQueueDispose(q, true)
    queue = nil
    
    isRunning = false
    isPaused = false
    
    // We might want to recreate the queue immediately so it's ready for next play?
    // But usually stop() means we are done. 
    // If user calls play() again, we check guard let q = queue in play(), 
    // so we should recreate it there or here.
    // Let's leave it nil and recreate in play() or feed() if needed, 
    // but better to recreate now if the lifecycle expects it.
    // However, createQueue() is fast.
    
    return true
  }

  func pause() -> Bool {
    guard let q = queue else { return false }
    let status = AudioQueuePause(q)
    if status == noErr {
        isPaused = true
        return true
    }
    return false
  }

  func resume() -> Bool {
    guard let q = queue else { return false }
    let status = AudioQueueStart(q, nil)
    if status == noErr {
        isPaused = false
        return true
    }
    return false
  }

  func feed(data: [UInt8], onDone: @escaping (_ r: Bool) -> Void) {
    // If queue is nil (e.g. after stop), recreate it
    if queue == nil {
        createQueue()
    }
    
    guard let q = queue else {
        onDone(false)
        return
    }
    
    // 1. Allocate AudioQueue buffer
    var bufferRef: AudioQueueBufferRef? = nil
    let dataSize = UInt32(data.count)
    
    let allocStatus = AudioQueueAllocateBuffer(q, dataSize, &bufferRef)
    guard allocStatus == noErr, let buf = bufferRef else {
        NSLog("RawSoundPlayer: Buffer allocation failed: \(allocStatus)")
        onDone(false)
        return
    }
    
    // 2. Copy data into buffer
    // buf.pointee.mAudioData is a void* (UnsafeMutableRawPointer)
    data.withUnsafeBytes { rawBufferPointer in
        if let baseAddress = rawBufferPointer.baseAddress {
            memcpy(buf.pointee.mAudioData, baseAddress, Int(dataSize))
        }
    }
    buf.pointee.mAudioDataByteSize = dataSize
    
    // 3. Enqueue buffer
    let enqueueStatus = AudioQueueEnqueueBuffer(q, buf, 0, nil)
    if enqueueStatus != noErr {
        NSLog("RawSoundPlayer: Enqueue failed: \(enqueueStatus)")
        // Free buffer if enqueue failed to avoid leak
        AudioQueueFreeBuffer(q, buf)
        onDone(false)
        return
    }
    
    // Success
    onDone(true)
  }

  func setVolume(_ volume: Float) -> Bool {
    self.volume = volume
    if let q = queue {
        let status = AudioQueueSetParameter(q, kAudioQueueParam_Volume, volume)
        return status == noErr
    }
    return true
  }
}
