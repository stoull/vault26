//
//  HTTPSTLSConfiguration.swift
//  MQTTClientServer
//
//  生产环境 HTTPS：在 `.env` 或进程环境中设置 `TLS_CERT_PATH`、`TLS_KEY_PATH`（PEM），
//  启动时使用 Hummingbird ``HTTPServerBuilder/tls(tlsConfiguration:)`` 包裹 HTTP/1。
//

import Foundation
import Hummingbird
import HummingbirdTLS
import NIOSSL

enum HTTPSTLSConfigurationError: Error, CustomStringConvertible {
    case tlsKeyPathMissing
    case tlsCertPathMissing
    case tlsPemContainsNoCertificates

    var description: String {
        switch self {
        case .tlsKeyPathMissing:
            return "已设置 TLS_CERT_PATH 但未设置 TLS_KEY_PATH（或为空）"
        case .tlsCertPathMissing:
            return "已设置 TLS_KEY_PATH 但未设置 TLS_CERT_PATH（或为空）"
        case .tlsPemContainsNoCertificates:
            return "TLS_CERT_PATH 指向的 PEM 文件中未解析到任何证书"
        }
    }
}

enum HTTPSTLSConfiguration {
    /// 合并 `.env` 与系统环境（与 ``EnvLoader/loadEnv()`` 后读取可选变量一致）。
    static func mergedEnvironment() async throws -> Environment {
        try await Environment.dotEnv().merging(with: Environment())
    }

    /// 若 `TLS_CERT_PATH` 与 `TLS_KEY_PATH` 均非空则加载 PEM；仅配置其一则抛错。
    static func makeServerTLSConfigurationIfConfigured(env: Environment) throws -> TLSConfiguration? {
        let certPath = env.get("TLS_CERT_PATH")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let keyPath = env.get("TLS_KEY_PATH")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if certPath.isEmpty, keyPath.isEmpty { return nil }
        if certPath.isEmpty { throw HTTPSTLSConfigurationError.tlsCertPathMissing }
        if keyPath.isEmpty { throw HTTPSTLSConfigurationError.tlsKeyPathMissing }

        let certs = try NIOSSLCertificate.fromPEMFile(certPath)
        guard !certs.isEmpty else { throw HTTPSTLSConfigurationError.tlsPemContainsNoCertificates }
        let certificateChain = certs.map { NIOSSLCertificateSource.certificate($0) }
        let privateKey = try NIOSSLPrivateKey(file: keyPath, format: .pem)
        return TLSConfiguration.makeServerConfiguration(
            certificateChain: certificateChain,
            privateKey: .privateKey(privateKey)
        )
    }

    /// `HTTP_PORT`：监听端口，默认 8044。
    static func httpListenPort(env: Environment) -> Int {
        env.get("HTTP_PORT", as: Int.self) ?? 8044
    }
}
