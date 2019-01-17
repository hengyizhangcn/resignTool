# resignTool
resign app command line tool

This tool can be used to resign the ipa with new embeded mobileprovision, or just change the version of ipa.

> There are four options:  
> `-h` Show help.  
> `-i` The path of .ipa file. This is nesscessary!  
> `-m` The path of .mobileprovision file. If not point out, the mobileprovision wouldn't change.  
> `-v` The new version of the app.  

How to use:

```bash
./resignTool -h #show help
```

```bash
./resignTool -i /Users/hengyi.zhang/Desktop/MyApp.ipa -m /Users/hengyi.zhang/Desktop/embedded.mobileprovision -v 5.0.0
#specify ipa path，mobileprovision path and new version
```

```bash
./resignTool -v 4.4.3 #directly change the version of ipa, (If you find there is wrong with the version after the archiving operation.)
```

Anyway, if your don't set the new version, the default operation is adding 1 to the last part of the version.
(Like 3.4.5 -> 3.4.6, and 3.4.A1 -> 3.4.1)

The path of the new ipa:
> There is a `new App` folder as the peer directory as the resignTool, the new ipa is in it.
