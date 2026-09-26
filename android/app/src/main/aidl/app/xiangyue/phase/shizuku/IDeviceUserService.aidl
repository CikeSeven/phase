package app.xiangyue.phase.shizuku;
import android.os.Bundle;
import android.os.IBinder;
import android.os.ParcelFileDescriptor;
import app.xiangyue.phase.shizuku.IDeviceCallback;
interface IDeviceUserService {
    Bundle probe() = 0;
    void execute(in Bundle request, in ParcelFileDescriptor screenshot, IDeviceCallback callback, IBinder client) = 1;
    void cancel(String owner, String call) = 2;
    void release(String owner) = 3;
    void destroy() = 16777114;
}
