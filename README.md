# a react-native plugin for compress photo or video  
## install  
`npm install react-native-export-asset --save`  
link dependency:  
`react-native link react-native-export-asset`  

## usage  
    import { NativeModules } from 'react-native';  
    // compress photo  
    var compressOptions = {maxWidth: 1024, maxHeight: 1024, quality: 0.8};
    var opt = {file: 'file path to the photo'};
    NativeModules.AssetExport.exportPhoto(Object.assign(opt, compressOptions), (path, code) => {
        if(code > 0){
            console.log(path);// the path is the compressed photo path
        }
        else{
            this.onFailed && this.onFailed(path);
        }
    });  
    // compress video  
    NativeModules.AssetExport.exportVideo(this.props.video, {width, height} ,uri => {
        if(uri.startsWith('file://'))
            uri = uri.substring(7);
        console.log(uri);// the uri is the compressed video path
    });
