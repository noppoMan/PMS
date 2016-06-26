//
//  WorkerObserver.swift
//  PMS
//
//  Created by Yuki Takei on 6/25/16.
//
//

func observeWorker(_ worker: inout Worker, execPath: String){
    worker.on { event in
        switch event {
        case .online:
            logger.info("Worker [\(worker.id)] is online")
        case .message(let message):
            logger.info("\(message)")
        case .exit(let status):
            logger.info("Worker [\(worker.id)] was exited with \(status)")
            if status > 0 {
                worker = try! Cluster.fork(execPath: execPath, silent: false)
                observeWorker(&worker, execPath: execPath)
            }
        default:
            noop()
        }
    }
}
