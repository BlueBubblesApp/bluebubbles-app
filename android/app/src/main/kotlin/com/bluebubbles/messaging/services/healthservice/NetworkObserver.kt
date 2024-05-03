package com.bluebubbles.messaging.services.healthservice

import android.content.Context
import android.net.ConnectivityManager
import android.net.ConnectivityManager.NetworkCallback
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class NetworkObserver(context: Context) {
    enum class ConnectionState {
        CONNECTED,
        DISCONNECTED,

        UNKNOWN
    }

    private val _internetState = MutableStateFlow(ConnectionState.UNKNOWN)
    val internetState = _internetState.asStateFlow()

    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val internetObserver = Observer(_internetState)

    fun start() {
        connectivityManager.registerNetworkCallback(internetNetwork, internetObserver)
    }

    fun stop() {
        connectivityManager.unregisterNetworkCallback(internetObserver)
    }

    private class Observer(val mutableState: MutableStateFlow<ConnectionState>): NetworkCallback(),
        CoroutineScope by CoroutineScope(Dispatchers.IO) {

        override fun onAvailable(network: Network) {
            super.onAvailable(network)

            launch {
                mutableState.emit(ConnectionState.CONNECTED)
            }
        }

        override fun onUnavailable() {
            super.onUnavailable()

            launch {
                mutableState.emit(ConnectionState.DISCONNECTED)
            }
        }

        override fun onLost(network: Network) {
            super.onLost(network)

            launch {
                mutableState.emit(ConnectionState.DISCONNECTED)
            }
        }
    }

    companion object {
        private val internetNetwork = NetworkRequest
            .Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
    }
}