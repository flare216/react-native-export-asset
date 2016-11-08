const fs = require('fs');

const androidProjectSettingsPath = process.cwd() + '/android/settings.gradle';
const pattern = 'include \':react-native-export-asset\'\n';
const libToAdd = 'include \':ffmpeg4android_lib\'\nproject(\':ffmpeg4android_lib\').projectDir = new File(rootProject.projectDir, \'../node_modules/react-native-export-asset/android/libs/ffmpeg4android_lib\')\n';

fs.writeFileSync(androidProjectSettingsPath, fs
	.readFileSync(androidProjectSettingsPath, 'utf8')
	.replace(pattern, match => `${libToAdd}${match}`)
	);