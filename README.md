# AppleTrace

## 使用说明
1. 准备MonkeyDev环境
2. 使用MonkeyDev安装下面两个目录的工具  
a) appletrace ：hook主要逻辑  
b) trace ：控制开始结束  
3. 安装issh：  
修改issh.sh里的trace输出目录outTracePath  
执行目录下的install.sh
4. 安装其他依赖工具：rsync/iproxy
5. 端口映射：iproxy 2222 22
6. issh shell连接手机
7. issh setpid 设置你想抓trace的进程
8. issh trace 自动抓取trace，默认5s  
会自动使用rsync命令pull到当前目录，并执行merge，结果*.json文件使用chrome://tracing打开

## MainFeature：
- 可以控制开始结束点，可设置抓取时间
- 运行时注入或冷启动进程的注入都可以
- 添加方法参数内容打印，见hook_objc_msgSend.m的LOG_ARGS
- 任意进程抓取，去掉对AppList/PreferenceLoader的依赖（经测试部分系统进程无法抓取）
- 多进程抓取，最终合并到一个trace文件展示
- 工程自动化：appletrace.framework编译完自动拷贝到loader并签名
- 添加进程线程名

## bugfix：
- Ios13上部分系统进程缺少_TEXT段时空指针的崩溃

## TODO：
- 动态设置trace级别
- 其他库打印

## 依赖
- Cydia rsync  文件传输
- mobile substrate
- MonkeyDev




`AppleTrace` is developed for analyzing app's performance on `iOS`.

*>> I have developed a replacement called [Messier](https://messier.app/) which is more easier to use. :)*

![logo](/image/appletrace-small.png)

- [中文说明，开发思路及方法](http://everettjf.github.io/2017/09/21/appletrace/)
- [搭载MonkeyDev可trace第三方App](http://everettjf.github.io/2017/10/12/appletrace-dancewith-monkeydev/)

![appletrace](https://everettjf.github.io/stuff/appletrace/appletrace.gif)



## Feature

1. User-defined trace section.
2. Trace Objective C methods.

## FAQ

[Go to Wiki](https://github.com/everettjf/AppleTrace/wiki)

## Clone

```
git clone https://github.com/everettjf/AppleTrace.git
```

For stable release , please refer to [Releases](https://github.com/everettjf/AppleTrace/releases)

## Usage

1. Produce trace data.
2. Copy from app's sandbox directory.
3. Merge (all) trace data files into one file `trace.json`. (There may be more than 1 trace file.)
4. Generate `trace.html` based on `trace.json`.

See below for more detail.

### 1. Produce


Until now , there are 2 ways for generating trace data.

(1) Manual set section.

Call `APTBeginSection` at the beginning of method ,and `APTEndSection` at the end of method. For Objective C method (whether instance method or class method), there are `APTBegin` and `APTEnd` macro for easy coding.
	
```
void anyKindsOfMethod{
    APTBeginSection("process");
    // some code
    APTEndSection("process");
}

- (void)anyObjectiveCMethod{
    APTBegin;
    // some code
    APTEnd;
}
```
	
Sample app is `sample/ManualSectionDemo`.
	
(2) Dynamic library hooking all objc_msgSend.

Hooking all objc_msgSend methods (based on HookZz). This only support arm64 under debugger ( lldb).

Sample app is `sample/TraceAllMsgDemo`.

### 2. Copy

Using any kinds of method, copy `<app's sandbox>/Library/appletracedata` out of Simulator/RealDevice.

![appletracedata](image/appletracedata.png)


### 3. Merge

Merge/Preprocess the `appletracedata`.

```
python merge.py -d <appletracedata directory>
```

This will produce `trace.json` in appletracedata directory.

NOW !!!, you could drop `trace.json` into Chrome's `chrome://tracing`. Or if you want to generate a html result, continue to the 4th step.

### 4. Generate

Run `sh get_catapult.sh` to get catapult source.

Then generate `trace.html` using `catapult`.

```
python catapult/tracing/bin/trace2html appletracedata/trace.json --output=appletracedata/trace.html
open trace.html
```

*trace.html only support Chrome*

## SampleData

Open `sampledata/trace.html` using Chrome.

## Thanks

1. HookZz : https://github.com/jmpews/HookZz
2. catapult : https://github.com/catapult-project/catapult
3. issh : https://github.com/4ch12dy/issh
## Group

欢迎关注微信订阅号，更多有趣的性能优化点点滴滴。

![fun](https://everettjf.github.io/images/fun.jpg)


