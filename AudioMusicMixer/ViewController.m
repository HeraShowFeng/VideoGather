//
//  ViewController.m
//  AudioMusicMixer
//
//  Created by shiwei on 17/11/2.
//  Copyright © 2017年 shiwei. All rights reserved.
//

#import "ViewController.h"
#import "TFMusicListViewController.h"
#import "TFAudioFileReader.h"
#import "TFAudioFileWriter.h"
#import "TFMediaListViewController.h"
#import "TFAudioUnitPlayer.h"
#import "AUGraphMixer.h"

#define SimultaneousRecordAndMix    1
#define MixPcmData  1

#define TestAUGraphMixer 1      //使用audioUnit graph 实现音频文件和录音混音，再实时播放的需求

@interface ViewController (){
    
    TFMediaData *_selectedMusic;
    TFAudioFileReader *_fileReader;
    
    TFMediaData *_selectedMusic2;
    AUGraphMixer * _AUGraphMixer;

    TFAudioFileWriter *_writer;
    
    NSString *_curRecordPath;
    TFAudioUnitPlayer *_audioPlayer;
    
}
@property (weak, nonatomic) IBOutlet UILabel *musicLabel;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@property (nonatomic, copy) NSString *recordHome;

@property (strong, nonatomic) IBOutletCollection(UISlider) NSArray<UISlider *> *volumeSliders;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _musicLabel.text = @"music1: ~\nmusic2: ~";
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"selectMusic"]) {
        TFMusicListViewController *destVC = segue.destinationViewController;
        destVC.selectMusicConpletionHandler = ^(TFMediaData *music){
            if (!_selectedMusic) {
                _selectedMusic = music;
                _musicLabel.text = [NSString stringWithFormat:@"music1: %@\nmusic2: ~",music.filename];
            }else{
                _selectedMusic2 = music;
                _musicLabel.text = [NSString stringWithFormat:@"music1: %@\nmusic2: %@",_selectedMusic.filename,_selectedMusic2.filename];
            }
        };
    }
}

-(BOOL)mixRuning{
    return _AUGraphMixer.isRuning;
}

- (IBAction)recordOrStop:(UIButton *)button {
    [self AUGraphMixerStartOrStop:button];
    
    if ([self mixRuning]) {
        [button setTitle:@"stop" forState:(UIControlStateNormal)];
    }else{
        [button setTitle:@"run" forState:(UIControlStateNormal)];
    }
}

-(void)AUGraphMixerStartOrStop:(UIButton *)sender{
    if ([self mixRuning]) {
        [_AUGraphMixer stop];
    }else{
        
        if (!_AUGraphMixer) {
            [self setupGraphMixer];
        }
        _AUGraphMixer.musicFilePath = _selectedMusic.filePath;
        _AUGraphMixer.musicFilePath2 = _selectedMusic2.filePath;
        [_AUGraphMixer start];
    }
}

-(void)setupGraphMixer{
    _AUGraphMixer = [[AUGraphMixer alloc] init];
    for (int i = 0; i<_volumeSliders.count; i++) {
        [_AUGraphMixer setVolumeAtIndex:i to:_volumeSliders[i].value];
    }
    _AUGraphMixer.outputPath = [self nextRecordPath];
    [_AUGraphMixer setupAUGraph];
}
- (IBAction)playbackChange:(UIButton *)sender {
    sender.selected = !sender.isSelected;
    if (sender.selected) {
        _AUGraphMixer.playBack = NO;
    } else {
        _AUGraphMixer.playBack = YES;
    }
}
- (IBAction)musicOnlyOne:(UIButton *)sender {
    sender.selected = !sender.isSelected;
    if (sender.selected) {
        _AUGraphMixer.onlyOne = YES;
    } else {
        _AUGraphMixer.onlyOne = NO;
    }
}

- (IBAction)mixTypeChange:(UIButton *)sender {
    
    if (!_AUGraphMixer) {
        [self setupGraphMixer];
    }
    
    NSInteger index = sender.tag - 100;
    AUGraphMixerChannelType type = [_AUGraphMixer channelTypeForSourceAt:index];
    
    if (type == AUGraphMixerChannelTypeLeft) {
        
        [_AUGraphMixer setAudioSourceAtIndex:index channelTypeTo:(AUGraphMixerChannelTypeRight)];
        [sender setTitle:@"右声道" forState:(UIControlStateNormal)];
        
    }else if (type == AUGraphMixerChannelTypeRight){
        
        [_AUGraphMixer setAudioSourceAtIndex:index channelTypeTo:(AUGraphMixerChannelTypeStereo)];
        [sender setTitle:@"双声道" forState:(UIControlStateNormal)];
        
    }else if (type == AUGraphMixerChannelTypeStereo){
        
        [_AUGraphMixer setAudioSourceAtIndex:index channelTypeTo:(AUGraphMixerChannelTypeLeft)];
        [sender setTitle:@"左声道" forState:(UIControlStateNormal)];
    }
}

-(NSString *)recordHome{
    if (!_recordHome) {
        _recordHome = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"audioMusicMix"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_recordHome]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_recordHome withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    
    return _recordHome;
}

-(NSString *)nextRecordPath{
    NSString *name = [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]];
    
    _curRecordPath = [self.recordHome stringByAppendingPathComponent:name];
    
    return _curRecordPath;
}

- (IBAction)showMixedList:(id)sender {
    TFMediaListViewController *mediaListVC = [[TFMediaListViewController alloc] init];
    mediaListVC.mediaDir = self.recordHome;
    
    mediaListVC.selectHandler = ^(TFMediaData *mediaData){
        NSLog(@"select audio file %@",mediaData.filename);
        
        //play audio file
        if (mediaData.isAudio) {
            if (!_audioPlayer) {
                _audioPlayer = [[TFAudioUnitPlayer alloc] init];
            }
            NSLog(@"play mixed");
            [_audioPlayer playLocalFile:mediaData.filePath];
        }
    };
    
    mediaListVC.disappearHandler = ^(){
        [_audioPlayer stop];
    };
    
    [self.navigationController pushViewController:mediaListVC animated:YES];
}

- (IBAction)volumeChanged:(UISlider *)slider {
    NSInteger index = [_volumeSliders indexOfObject:slider];
    [_AUGraphMixer setVolumeAtIndex:index to:slider.value];
}

@end
