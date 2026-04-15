//
//  EnvLoader.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/15.
//

import Foundation
import Hummingbird

enum EnvLoaderError: Error {
    case invalidEvn
}

struct EnvLoader {
    
    static var shared = EnvLoader()
    
    var MQTT_HOST: String?
    var MQTT_PORT: Int?
    var MQTT_USERNAME: String?
    var MQTT_PASSWORD: String?
    
    var DB_HOST: String?
    var DB_PORT: Int?
    var DB_USERNAME: String?
    var DB_PASSWORD: String?
    var DB_DATABASE: String?
    
//    public static func checkEnv() async throws -> EnvLoader{
//        var envLoad = EnvLoader()
//        try await envLoad.loadEnv()
//        return envLoad;
//    }
    
    public mutating func loadEnv() async throws{
        // 1. 加载系统环境变量（当前进程的环境变量）
        let systemEnv = Environment()
        
        let syste_pwd = systemEnv.get("pwd", as: String.self)
        logger.info("pwd-path: \(syste_pwd ?? "")")
        
        var hb_env = systemEnv
        
        var isSysEnvRequired = false
        do {
            // 尝试从系统中加载App所需的变量
            MQTT_HOST = try hb_env.require("MQTT_HOST", as: String.self)
            MQTT_PORT = try hb_env.require("MQTT_PORT", as: Int.self)
            MQTT_USERNAME = try hb_env.require("MQTT_USERNAME", as: String.self)
            MQTT_PASSWORD = try hb_env.require("MQTT_PASSWORD", as: String.self)
            
            DB_HOST = try hb_env.require("DB_HOST", as: String.self)
            DB_PORT = try hb_env.require("DB_PORT", as: Int.self)
            DB_USERNAME = try hb_env.require("DB_USERNAME", as: String.self)
            DB_PASSWORD = try hb_env.require("DB_PASSWORD", as: String.self)
            DB_DATABASE = try hb_env.require("DB_DATABASE", as: String.self)
            isSysEnvRequired = true
            logger.info("进程的环境变量中加载所需的变量成功！")
        } catch {
            logger.info("进程的环境变量中没有所需的变量！如果是正式环境，检查./run.sh文件,其中用到./Sources/App/.env文件，并增加对应的变量")
        }
        
        // 2. 加载 .env 文件中的变量 默认路私为pwd 的 ./.env
        let dotEnv = try await Environment.dotEnv()
        
        /**
         加载指定路径的env
         guard let configUrl = Bundle.module.url(forResource: "config", withExtension: "json") else {
         fatalError("找不到config 文件")
         }
         
         guard let envFileURL = Bundle.module.url(forResource: "env", withExtension: nil) else {
         fatalError("找不到 .env 文件")
         }
         
         // 使用文件的绝对路径加载
         let dotEnv = try await Environment.dotEnv(envFileURL.path)
         */
        
        // 3. 合并：将 .env 变量合并到系统变量中
        // let env = dotEnv.merging(with: systemEnv)
        
        if (!isSysEnvRequired) {
            // 如果系统变量中没有，则尝试从.evn文件中加载App所需的变量
            hb_env = dotEnv
            do {
                MQTT_HOST = try hb_env.require("MQTT_HOST", as: String.self)
                MQTT_PORT = try hb_env.require("MQTT_PORT", as: Int.self)
                MQTT_USERNAME = try hb_env.require("MQTT_USERNAME", as: String.self)
                MQTT_PASSWORD = try hb_env.require("MQTT_PASSWORD", as: String.self)
                
                DB_HOST = try hb_env.require("DB_HOST", as: String.self)
                DB_PORT = try hb_env.require("DB_PORT", as: Int.self)
                DB_USERNAME = try hb_env.require("DB_USERNAME", as: String.self)
                DB_PASSWORD = try hb_env.require("DB_PASSWORD", as: String.self)
                DB_DATABASE = try hb_env.require("DB_DATABASE", as: String.self)
                logger.info(".env文件中加载所需的变量成功！")
            } catch {
                logger.info("系统和.env文件中都未包所需的变量！")
                logger.info("如果是调试环境，检查./Sources/App/.env文件，并增加对应的变量")
                throw EnvLoaderError.invalidEvn
            }
        }
    }
    
    // 使用Swift系统自带的，而非Hummingbird中的工具加载环境变量
    mutating func loadEnvUseSysTools() {
        DB_HOST =        env("DB_HOST",      "macmini.local")
        DB_PORT =        envInt("DB_PORT",   3306)
        DB_USERNAME =    env("DB_USERNAME",  "username")
        DB_PASSWORD =    env("DB_PASSWORD",  "user_password")
        DB_DATABASE =    env("DB_DATABASE",  "home_db")
        
        // MQTT 配置
        MQTT_HOST =      env("MQTT_HOST",    "macmini.local")
        MQTT_PORT =      envInt("MQTT_PORT", 1883)
        MQTT_USERNAME =  env("MQTT_USERNAME", "username")
        MQTT_PASSWORD =  env("MQTT_PASSWORD", "user_password")
    }
}

// MARK: - 环境变量工具
private func env(_ key: String, _ fallback: String) -> String {
    ProcessInfo.processInfo.environment[key] ?? fallback
}
private func envInt(_ key: String, _ fallback: Int) -> Int {
    Int(ProcessInfo.processInfo.environment[key] ?? "") ?? fallback
}
private func envInt64(_ key: String, _ fallback: Int64) -> Int64 {
    Int64(ProcessInfo.processInfo.environment[key] ?? "") ?? fallback
}
