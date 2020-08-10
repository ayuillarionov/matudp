cxt = NCCLab_DisplayContext();
si = ScreenInfo(1, cxt.cs);
si.open
eli = EyeLinkInfo(si, 'DemoTest', 'MyPreableText');
[result, messageString] = eli.doTrackerSetup()