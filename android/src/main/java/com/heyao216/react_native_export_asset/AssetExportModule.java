package com.heyao216.react_native_export_asset;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.net.Uri;
import android.provider.MediaStore;
import android.util.Log;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.Callback;
import com.netcompss.loader.LoadJNI;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.UUID;

/**
 * Created by heyao on 16/8/16.
 */
public class AssetExportModule extends ReactContextBaseJavaModule{
    public static LoadJNI vk = null;
    private ReactApplicationContext _context = null;
    public AssetExportModule(ReactApplicationContext reactContext) {
        super(reactContext);
        _context = reactContext;
    }

    @Override
    public String getName() {
        return "AssetExport";
    }

    @ReactMethod
    public void exportVideo(final String path, final ReadableMap options ,final Callback callback) {
        if (AssetExportModule.vk == null) {
            AssetExportModule.vk = new LoadJNI();
        }
        String workFolder = _context.getApplicationContext().getFilesDir().getAbsolutePath();
        File f = new File(path);
        int width = options.getInt("width");
        int height = options.getInt("height");
        String fileName = f.getName();
        String foldName = f.getParent();
        String outputName = foldName + "/tmp.mp4";
        String[] complexCommand = {"ffmpeg", "-y", "-i", path, "-strict", "experimental", "-s", height + "x" + width, "-r", "25", "-vcodec", "mpeg4", "-b", "2300k", "-ab", "48000", "-ac", "2", "-ar", "22050", outputName};
        Thread t = new Thread(new Compress(complexCommand, workFolder, outputName ,_context, callback));
        t.start();
    }

    @ReactMethod
    public void exportPhoto(ReadableMap photo, final Callback callback){
        int maxWidth = photo.getInt("maxWidth");
        int maxHeight = photo.getInt("maxHeight");
        double quality = photo.getDouble("quality");
        String path = photo.getString("file");
        Uri uri = Uri.parse(path);
        File fs = getResizedImage(getRealPathFromURI(uri), maxWidth, maxHeight, (int)(quality * 100));
        callback.invoke(fs.getAbsolutePath(), 1);
    }

    /**
     * Create a resized image to fulfill the maxWidth/maxHeight, quality and rotation values
     *
     * @param realPath
     * @return resized file
     */
    private File getResizedImage(final String realPath, int maxWidth, int maxHeight , final int quality) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inScaled = false;
        Bitmap photo = BitmapFactory.decodeFile(realPath, options);
        int initialWidth = photo.getWidth();
        int initialHeight = photo.getHeight();

        if (photo == null) {
            return null;
        }

        Bitmap scaledphoto = null;
        if (maxWidth == 0) {
            maxWidth = initialWidth;
        }
        if (maxHeight == 0) {
            maxHeight = initialHeight;
        }
        double widthRatio = (double) maxWidth / initialWidth;
        double heightRatio = (double) maxHeight / initialHeight;

        double ratio = (widthRatio < heightRatio)
                ? widthRatio
                : heightRatio;

        Matrix matrix = new Matrix();
//        matrix.postRotate(rotation);
        matrix.postScale((float) ratio, (float) ratio);

        ExifInterface exif;
        try {
            exif = new ExifInterface(realPath);

            int orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, 0);

            if (orientation == 6) {
                matrix.postRotate(90);
            } else if (orientation == 3) {
                matrix.postRotate(180);
            } else if (orientation == 8) {
                matrix.postRotate(270);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }

        scaledphoto = Bitmap.createBitmap(photo, 0, 0, photo.getWidth(), photo.getHeight(), matrix, true);
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        scaledphoto.compress(Bitmap.CompressFormat.JPEG, quality, bytes);

        File f = createNewFile(false);
        FileOutputStream fo;
        try {
            fo = new FileOutputStream(f);
            try {
                fo.write(bytes.toByteArray());
            } catch (IOException e) {
                e.printStackTrace();
            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }

        // recycle to avoid java.lang.OutOfMemoryError
        if (photo != null) {
            scaledphoto.recycle();
            photo.recycle();
            scaledphoto = null;
            photo = null;
        }
        return f;
    }

    private File createNewFile(final boolean forcePictureDirectory) {
        String filename = "image-" + UUID.randomUUID().toString() + ".jpg";
//        if (false && forcePictureDirectory != true) {
            return new File(_context.getCacheDir(), filename);
//        } else {
//            File path = Environment.getExternalStoragePublicDirectory(
//                    Environment.DIRECTORY_PICTURES);
//            File f = new File(path, filename);
//
//            try {
//                path.mkdirs();
//                f.createNewFile();
//            } catch (IOException e) {
//                e.printStackTrace();
//            }
//            return f;
//        }
    }

    private String getRealPathFromURI(Uri uri) {
        String result;
        String[] projection = {MediaStore.Images.Media.DATA};
        Cursor cursor = _context.getContentResolver().query(uri, projection, null, null, null);
        if (cursor == null) { // Source is Dropbox or other similar local file path
            result = uri.getPath();
        } else {
            cursor.moveToFirst();
            int idx = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA);
            result = cursor.getString(idx);
            cursor.close();
        }
        return result;
    }
}

class Compress implements Runnable{
    private ReactApplicationContext _context = null;
    private String[] _cmd = null;
    private String _workFold = null;
    private Callback _callback = null;
    private String _outputName = null;
    public Compress(String[] cmd, String workFolder, String outputName ,ReactApplicationContext context, Callback callback){
        _context = context;
        _cmd = cmd;
        _workFold = workFolder;
        _callback = callback;
        _outputName = outputName;
    }

    public void run(){
        try {
            AssetExportModule.vk.run(_cmd , _workFold, _context);
            Log.i("test", "ffmpeg4android finished successfully");
            _callback.invoke(_outputName);
        } catch (Throwable e) {
            Log.e("test", "vk run exception.", e);
        }
    }
}
