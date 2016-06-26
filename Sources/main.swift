//
//  main.swift
//  PMS
//
//  Created by Yuki Takei on 6/25/16.
//
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif


let logger = Logger(name: "PMS", appender: PMSStdoutAppender(), levels: .info)

func noop(){}

try! Program(command: "start <path>", options: [
    Option(short: "i", long: "cpu [num]", desc: "The number of cpu using"),
    Option(short: "p", long: "port [port]", desc: "The port number to bind"),
    Option(short: "b", long: "bind [address]", desc: "The host address to bind")
])
.action { subCommands, options in
    guard let execPath = subCommands["path"] else {
        return
    }
    
    let cpus = OS.cpus()
    
    var cpu = options["i"] ?? "1"
    if cpu == "--max" {
        cpu = "\(cpus.count)"
    }
    
    let PORT = Int(options["p"] ?? "3000") ?? 3000
    let HOST = options["h"] ?? "0.0.0.0"
    
    let MAX_WORKES = 64
    let numOfWorkers = Int(cpu) ?? 1
    if numOfWorkers > MAX_WORKES {
        print("Could not fork over \(MAX_WORKES) worksers")
        exit(1)
    }
    
    var workers = [Worker]()
    
    func createWorker() throws {
        var worker = try Cluster.fork(execPath: execPath, silent: false)
        observeWorker(&worker, execPath: execPath)
        workers.append(worker)
    }
    
    do {
        for _ in 0..<numOfWorkers {
            try createWorker()
        }
        
        let usr2Signal = SignalWrap()
        usr2Signal.start(SIGUSR2) { _ in
            do {
                let oldWorkers = workers
                logger.info("Got USR2 Signal............")
                logger.info("Start to fork new children......")
                for _ in 0..<numOfWorkers {
                    try createWorker()
                }
                
                let t = TimerWrap(tick: 5000)
                t.start {
                    t.end()
                    do {
                        for worker in oldWorkers {
                            try worker.kill(SIGTERM)
                            if let index = workers.index(of: worker) {
                                workers.remove(at: index)
                            }
                        }
                        logger.info("Old workers are killed")
                    } catch {
                        logger.fatal("\(error)")
                        exit(1)
                    }
                }
            } catch {
                logger.fatal("\(error)")
                exit(1)
            }
        }
        
        let ttinSignal = SignalWrap()
        ttinSignal.start(SIGTTIN) { _ in
            do {
                try createWorker()
                logger.info("active workers count: \(workers.count)")
            } catch {
                logger.fatal("\(error)")
                exit(1)
            }
        }
        
        let ttouSignal = SignalWrap()
        ttouSignal.start(SIGTTOU) { _ in
            do {
                let index = 0
                if workers.count > 0 {
                    try workers[index].kill(SIGTERM)
                    workers.remove(at: index)
                    logger.info("active workers count: \(workers.count)")
                }
            } catch {
                logger.fatal("\(error)")
                exit(1)
            }
        }
        
        let server = Skelton(ipcEnable: false, onConnection: { _ in })
        try server.bind(host: HOST, port: PORT)
        try server.listen()
    } catch {
        logger.fatal("\(error)")
        exit(1)
    }
}

Program.parse(Process.arguments)