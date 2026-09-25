package app.xiangyue.phase.commands;
import android.os.Bundle;
import android.os.IBinder;
import android.os.ParcelFileDescriptor;
import app.xiangyue.phase.commands.ICommandCallback;
interface ICommandUserService {
    Bundle probe() = 0;
    void start(in Bundle spec, in ParcelFileDescriptor stdout, in ParcelFileDescriptor stderr, ICommandCallback callback, IBinder client) = 1;
    void transfer(in Bundle spec, in ParcelFileDescriptor socket, ICommandCallback callback, IBinder client) = 2;
    void cancel(String owner, String call) = 3;
    void destroy() = 16777114;
}
