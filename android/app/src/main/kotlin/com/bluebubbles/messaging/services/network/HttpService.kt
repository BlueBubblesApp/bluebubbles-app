package com.bluebubbles.messaging.services.network

import android.content.Context
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.utils.PersistentLog
import com.bluebubbles.messaging.utils.SettingsHelper
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import java.util.UUID

/**
 * HTTP Service for making API requests to the BlueBubbles server from native Kotlin code.
 * This mirrors the functionality of the Flutter HttpService for operations that need to
 * happen without spinning up a Flutter engine (e.g., notification replies, Google Assistant).
 * 
 * Based on: lib/services/network/http_service.dart
 */
class HttpService(private val context: Context) {
    
    private val settings = SettingsHelper(context)
    private val api: BlueBubblesApi
    
    companion object {
        private const val TAG = "HttpService"
        private const val DEFAULT_TIMEOUT_MS = 30000L
        private const val CLOUDFLARE_RETRY_ATTEMPTS = 2
    }
    
    init {
        api = createRetrofitInstance()
    }
    
    /**
     * Create the Retrofit instance with OkHttp client
     */
    private fun createRetrofitInstance(): BlueBubblesApi {
        val timeout = settings.apiTimeout.toLong()
        
        // Create logging interceptor
        val loggingInterceptor = HttpLoggingInterceptor { message ->
            PersistentLog.d(context, TAG, message)
        }.apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }
        
        // Create custom headers interceptor
        val headersInterceptor = Interceptor { chain ->
            val originalRequest = chain.request()
            val requestBuilder = originalRequest.newBuilder()
            
            // Add all custom headers
            settings.getAllHeaders().forEach { (key, value) ->
                requestBuilder.addHeader(key, value)
            }
            
            val request = requestBuilder.build()
            PersistentLog.d(context, TAG, "Request: [${request.method}] ${request.url}")

            val response = chain.proceed(request)
            PersistentLog.d(context, TAG, "Response: [${response.code}] ${request.url}")
            
            response
        }
        
        // Create OkHttp client
        val okHttpClient = OkHttpClient.Builder()
            .connectTimeout(timeout, TimeUnit.MILLISECONDS)
            .readTimeout(timeout, TimeUnit.MILLISECONDS)
            .writeTimeout(timeout, TimeUnit.MILLISECONDS)
            .addInterceptor(headersInterceptor)
            .addInterceptor(loggingInterceptor)
            .build()
        
        // Build base URL (API root)
        val baseUrl = if (settings.hasServerUrl()) {
            "${settings.apiRoot}/"
        } else {
            "http://localhost/" // Placeholder, will fail gracefully
        }
        
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(BlueBubblesApi::class.java)
    }
    
    /**
     * Send a text message to a chat
     * 
     * @param chatGuid The GUID of the chat to send to
     * @param message The message text to send
     * @param method Optional method for private API (e.g., "private-api")
     * @param effectId Optional iMessage effect (e.g., "com.apple.messages.effect.CKConfettiEffect")
     * @param subject Optional subject line
     * @param selectedMessageGuid Optional GUID of message to reply to
     * @param partIndex Optional part index for replies
     * @param ddScan Optional data detection scan flag
     * @param onSuccess Callback for successful response
     * @param onError Callback for error
     */
    fun sendMessage(
        chatGuid: String,
        message: String,
        method: String? = null,
        effectId: String? = null,
        subject: String? = null,
        selectedMessageGuid: String? = null,
        partIndex: Int? = null,
        ddScan: Boolean? = null,
        onSuccess: ((ApiResponse) -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        if (!validateConnection()) {
            onError?.invoke("No server URL configured")
            return
        }
        
        // Generate a temporary GUID to prevent duplicate messages
        val tempGuid = UUID.randomUUID().toString()
        
        // Build the request
        val request = SendMessageRequest(
            chatGuid = chatGuid,
            tempGuid = tempGuid,
            message = if (message.isEmpty() && !subject.isNullOrEmpty()) " " else message,
            method = method,
            effectId = if (settings.enablePrivateAPI && settings.privateAPISend) effectId else null,
            subject = if (settings.enablePrivateAPI && settings.privateAPISend) subject else null,
            selectedMessageGuid = if (settings.enablePrivateAPI && settings.privateAPISend) selectedMessageGuid else null,
            partIndex = if (settings.enablePrivateAPI && settings.privateAPISend) partIndex else null,
            ddScan = if (settings.enablePrivateAPI && settings.privateAPISend) ddScan else null
        )
        
        PersistentLog.i(context, TAG, "Sending message to chat: $chatGuid")
        
        executeApiCall(
            call = api.sendMessage(settings.guidAuthKey, request),
            onSuccess = onSuccess,
            onError = onError,
            retryOnCloudflare = true
        )
    }
    
    /**
     * Send a reply to a specific message
     * This is a convenience wrapper around sendMessage
     */
    fun sendReply(
        chatGuid: String,
        message: String,
        replyToGuid: String,
        partIndex: Int? = 0,
        onSuccess: ((ApiResponse) -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        sendMessage(
            chatGuid = chatGuid,
            message = message,
            selectedMessageGuid = replyToGuid,
            partIndex = partIndex,
            onSuccess = onSuccess,
            onError = onError
        )
    }
    
    /**
     * Send a tapback/reaction to a message
     * 
     * @param chatGuid The GUID of the chat
     * @param selectedMessageText The text of the message being reacted to
     * @param selectedMessageGuid The GUID of the message being reacted to
     * @param reaction The reaction type (e.g., "love", "like", "dislike", etc.)
     * @param partIndex Optional part index for multipart messages
     * @param onSuccess Callback for successful response
     * @param onError Callback for error
     */
    fun sendTapback(
        chatGuid: String,
        selectedMessageText: String,
        selectedMessageGuid: String,
        reaction: String,
        partIndex: Int? = null,
        onSuccess: ((ApiResponse) -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        if (!validateConnection()) {
            onError?.invoke("No server URL configured")
            return
        }
        
        val request = SendTapbackRequest(
            chatGuid = chatGuid,
            selectedMessageText = selectedMessageText,
            selectedMessageGuid = selectedMessageGuid,
            reaction = reaction,
            partIndex = partIndex
        )
        
        PersistentLog.i(context, TAG, "Sending tapback '$reaction' to message: $selectedMessageGuid in chat: $chatGuid")
        
        executeApiCall(
            call = api.sendTapback(settings.guidAuthKey, request),
            onSuccess = onSuccess,
            onError = onError,
            retryOnCloudflare = true
        )
    }
    
    /**
     * Ping the server to check connectivity
     */
    fun ping(
        onSuccess: ((ApiResponse) -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        if (!validateConnection()) {
            onError?.invoke("No server URL configured")
            return
        }
        
        executeApiCall(
            call = api.ping(settings.guidAuthKey),
            onSuccess = onSuccess,
            onError = onError,
            retryOnCloudflare = false
        )
    }
    
    /**
     * Validate that we have the necessary connection settings
     */
    private fun validateConnection(): Boolean {
        if (!settings.hasServerUrl()) {
            PersistentLog.e(context, TAG, "No server URL configured")
            return false
        }

        if (!settings.hasAuthKey()) {
            PersistentLog.e(context, TAG, "No auth key configured")
            return false
        }
        
        return true
    }
    
    /**
     * Execute an API call with error handling and optional retry for Cloudflare
     */
    private fun <T> executeApiCall(
        call: Call<T>,
        onSuccess: ((T) -> Unit)? = null,
        onError: ((String) -> Unit)? = null,
        retryOnCloudflare: Boolean = false,
        attemptNumber: Int = 1
    ) {
        call.enqueue(object : Callback<T> {
            override fun onResponse(call: Call<T>, response: retrofit2.Response<T>) {
                if (response.isSuccessful && response.body() != null) {
                    PersistentLog.d(context, TAG, "API call successful: ${response.code()}")
                    onSuccess?.invoke(response.body()!!)
                } else {
                    val errorMsg = "API call failed: ${response.code()} - ${response.message()}"
                    PersistentLog.e(context, TAG, errorMsg)

                    // Retry on 502 for Cloudflare
                    if (response.code() == 502
                        && retryOnCloudflare
                        && settings.apiRoot.contains("trycloudflare")
                        && attemptNumber < CLOUDFLARE_RETRY_ATTEMPTS
                    ) {
                        PersistentLog.w(context, TAG, "Retrying Cloudflare request (attempt ${attemptNumber + 1})")
                        executeApiCall(
                            call = call.clone(),
                            onSuccess = onSuccess,
                            onError = onError,
                            retryOnCloudflare = retryOnCloudflare,
                            attemptNumber = attemptNumber + 1
                        )
                    } else {
                        onError?.invoke(errorMsg)
                    }
                }
            }
            
            override fun onFailure(call: Call<T>, t: Throwable) {
                val errorMsg = "API call failed: ${t.message}"
                PersistentLog.e(context, TAG, errorMsg, t)
                onError?.invoke(errorMsg)
            }
        })
    }
}
