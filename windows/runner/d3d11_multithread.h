#ifndef RUNNER_D3D11_MULTITHREAD_H_
#define RUNNER_D3D11_MULTITHREAD_H_

// Workaround for flutter#196618: since 3.50 the engine's raster thread (presenting) and IO thread (resource GL work)
// can be inside ANGLE's D3D11 immediate context at the same time, which corrupts the driver's state and crashes in
// it. Turns on D3D's own multithread protection for every device the engine creates. Call before the engine starts.
void EnableEngineD3D11MultithreadProtection();

#endif  // RUNNER_D3D11_MULTITHREAD_H_
