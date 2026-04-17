//
//  APILanguageMiddleware.swift
//  MQTTClientServer
//
//  根据 `Accept-Language` 或查询参数 `lang` 设置 ``APII18n/language``，供 `_t(...)` 使用
//

import Hummingbird

struct APILanguageMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let lang = APILanguage.resolve(from: request)
        return try await APII18n.$language.withValue(lang) {
            try await next(request, context)
        }
    }
}
