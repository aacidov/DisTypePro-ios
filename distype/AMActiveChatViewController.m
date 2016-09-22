//
//  ActiveChatViewController.m
//  distype
//
//  Created by amakushkin on 13.09.16.
//  Copyright © 2016 aacidov. All rights reserved.
//

#import <LGAlertView.h>

#import "AMCategoryModel.h"
#import "AMChatMessageModel.h"
#import "AMChatTextInputView.h"
#import "AMWordCollectionViewCell.h"
#import "AMActiveChatViewController.h"

@interface AMActiveChatViewController ()
<
UITableViewDelegate,
UITableViewDataSource,
UIPickerViewDelegate,
UIPickerViewDataSource,
UICollectionViewDelegate,
UICollectionViewDataSource,
AMChatTextInputViewDelegate,
AMWordCollectionViewCellDelegate
>

- (void)initialize;
- (void)hideWordsKeyboard;
- (BOOL)isTextEmpty:(NSString*)text;
- (void)showWordsKeyboardForCategory:(NSString*)categoryUniqId;

@property (strong) NSString *cellIdentifier;
@property (assign) BOOL isNonStandartKeyboardUsed;

@property (strong) RLMResults *wordsForCategory;
@property (strong) RLMResults *categoryQueryResult;
@property (strong) AMChatMessageModel *temporaryMsg;
@property (strong) NSMutableArray<AMChatMessageModel*> *chatMessages;

@property (strong) LGAlertView *pickerActionSheet;
@property (strong) UICollectionView *categoryWordCollection;

@property (strong, nonatomic) IBOutlet UITableView *chatTable;
@property (strong, nonatomic) IBOutlet UIScrollView *mainScrollView;
@property (strong, nonatomic) IBOutlet AMChatTextInputView *chatMessageInput;

@end

@implementation AMActiveChatViewController

- (void)initialize {
    self.chatMessages = [[NSMutableArray alloc] init];
    self.cellIdentifier = [NSUUID UUID].UUIDString;
    
    self.chatTable.transform = CGAffineTransformMakeRotation(M_PI);
    self.chatTable.separatorColor = [UIColor clearColor];
    self.chatTable.delegate = self;
    self.chatTable.dataSource = self;
    [self.chatTable registerClass:[UITableViewCell class]
           forCellReuseIdentifier:self.cellIdentifier];
  
    self.chatMessageInput.delegate = self;
    
    CGRect rectCollection = CGRectMake(0,
                                       [UIScreen mainScreen].bounds.size.height + 10,
                                       [UIScreen mainScreen].bounds.size.width,
                                       [UIScreen mainScreen].bounds.size.height / 4);
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.itemSize = CGSizeMake(rectCollection.size.width / 4, rectCollection.size.height / 4);
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    flowLayout.estimatedItemSize = CGSizeMake(rectCollection.size.width / 4, rectCollection.size.height / 4);
    self.categoryWordCollection = [[UICollectionView alloc] initWithFrame:rectCollection collectionViewLayout:flowLayout];
    [self.categoryWordCollection registerNib:[UINib nibWithNibName:@"AMWordCollectionViewCell" bundle:nil]
                  forCellWithReuseIdentifier:[AMWordCollectionViewCell cellId]];
    self.categoryWordCollection.dataSource = self;
    self.categoryWordCollection.delegate = self;
    self.categoryWordCollection.backgroundColor = [UIColor whiteColor];
    
#warning Need to delete this code after implementing ChatsList
    /*
     START
     */
    self.conversationUniqId = [NSUUID UUID].UUIDString;
    
    RLMResults *resultsConversation = [AMChatMessageModel allObjects];
    
    for (AMChatMessageModel *obj in resultsConversation) {
        [self.chatMessages insertObject:obj atIndex:0];
    }
    /*
     END
     */
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initialize];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setConversationUniqId:(NSString *)conversationUniqId {
    if (self.chatMessages == nil) {
        self.chatMessages = [[NSMutableArray alloc] init];
    } else {
        [self.chatMessages removeAllObjects];
    }
    
    _conversationUniqId = conversationUniqId;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"conversationUniqId == %@", conversationUniqId];
    RLMResults *resultsConversation = [AMChatMessageModel objectsWithPredicate:predicate];
    
    for (AMChatMessageModel *obj in resultsConversation) {
        [self.chatMessages insertObject:obj atIndex:0];
    }
}

- (void)hideWordsKeyboard {
    self.isNonStandartKeyboardUsed = NO;
    self.chatMessageInput.hidden = NO;
    self.wordsForCategory = nil;
    
    [self.categoryWordCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
    
    CGPoint offset = CGPointZero;
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.5f animations:^{
        __strong typeof(weakSelf) self = weakSelf;
        self.mainScrollView.contentOffset = offset;
        self.categoryWordCollection.frame = CGRectMake(self.categoryWordCollection.frame.origin.x,
                                                       [UIScreen mainScreen].bounds.size.height + self.categoryWordCollection.frame.size.height,
                                                       self.categoryWordCollection.frame.size.width,
                                                       self.categoryWordCollection.frame.size.height);
    } completion:^(BOOL finished) {
        __strong typeof(weakSelf) self = weakSelf;
        [self.categoryWordCollection removeFromSuperview];
    }];
}

- (void)showWordsKeyboardForCategory:(NSString*)categoryUniqId {
    self.chatMessageInput.hidden = YES;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"categoryUniqId == %@", categoryUniqId];
    self.wordsForCategory = [AMChatMessageModel objectsWithPredicate:predicate];
    
    if (self.wordsForCategory.count > 0) {
        self.isNonStandartKeyboardUsed = YES;
        
        [self.view addSubview:self.categoryWordCollection];
        CGPoint scrollOffset = CGPointMake(self.mainScrollView.contentOffset.x,
                                           self.categoryWordCollection.frame.size.height);
        
        __weak typeof(self) weakSelf = self;
        [UIView animateWithDuration:0.5f animations:^{
            __strong typeof(weakSelf) self = weakSelf;
            self.mainScrollView.contentOffset = scrollOffset;
            self.categoryWordCollection.frame = CGRectMake(self.categoryWordCollection.frame.origin.x,
                                                           [UIScreen mainScreen].bounds.size.height - self.categoryWordCollection.frame.size.height,
                                                           self.categoryWordCollection.frame.size.width,
                                                           self.categoryWordCollection.frame.size.height);
        } completion:^(BOOL finished) {
            __strong typeof(weakSelf) self = weakSelf;
            [self.categoryWordCollection reloadData];
        }];
    } else {
        self.chatMessageInput.hidden = NO;
        self.isNonStandartKeyboardUsed = NO;
    }
}

- (BOOL)isTextEmpty:(NSString*)text {
    BOOL result = NO;
    
    if (text == nil
        || [text isEqualToString:@""] == YES) {
        result = YES;
    } else {
        NSRegularExpression *regexp = [[NSRegularExpression alloc] initWithPattern:@"^[ ]+$"
                                                                           options:NSRegularExpressionAnchorsMatchLines
                                                                             error:nil];
        if ([regexp matchesInString:text options:0 range:NSMakeRange(0, text.length)].count > 0) {
            result = YES;
        }
    }
    
    return result;
}

#pragma mark - Button events

- (IBAction)changeKeyboardAction:(UIBarButtonItem *)sender {
    if (self.isNonStandartKeyboardUsed == YES) {
        [self hideWordsKeyboard];
    } else {
        self.categoryQueryResult = [AMCategoryModel allObjects];
        
        if (self.categoryQueryResult.count > 0) {
            UIPickerView *categoryPicker = [[UIPickerView alloc] init];
            categoryPicker.delegate = self;
            categoryPicker.dataSource = self;
            
            __weak typeof(self) weakSelf = self;
            self.pickerActionSheet = [[LGAlertView alloc] initWithViewAndTitle:@"Select word category"
                                                                       message:nil
                                                                         style:LGAlertViewStyleActionSheet
                                                                          view:categoryPicker
                                                                  buttonTitles:@[@"Select"]
                                                             cancelButtonTitle:@"Cancel"
                                                        destructiveButtonTitle:nil
                                                                 actionHandler:^(LGAlertView *alertView, NSString *title, NSUInteger index) {
                                                                     __strong typeof(weakSelf) self = weakSelf;
                                                                     [self.pickerActionSheet dismissAnimated:YES completionHandler:nil];
                                                                     self.pickerActionSheet = nil;
                                                                     
                                                                     NSInteger row = [categoryPicker selectedRowInComponent:0];
                                                                     if (row >= 0) {
                                                                         AMCategoryModel *category = [self.categoryQueryResult objectAtIndex:row];
                                                                         [self showWordsKeyboardForCategory:category.categoryUniqId];
                                                                     }
                                                                 }
                                                                 cancelHandler:^(LGAlertView *alertView) {
                                                                     __strong typeof(weakSelf) self = weakSelf;
                                                                     [self.pickerActionSheet dismissAnimated:YES completionHandler:nil];
                                                                     self.pickerActionSheet = nil;
                                                                 }
                                                            destructiveHandler:nil];
            self.pickerActionSheet.cancelOnTouch = NO;
            
            [self.pickerActionSheet showAnimated:YES completionHandler:nil];
        } else {
            LGAlertView *alertView = [[LGAlertView alloc] initWithTitle:@"Error"
                                                                message:@"Words category doesn't exist yet. Please ad at least one word category"
                                                                  style:LGAlertViewStyleAlert
                                                           buttonTitles:@[@"Ok"]
                                                      cancelButtonTitle:nil
                                                 destructiveButtonTitle:nil];
            alertView.cancelOnTouch = NO;
            
            [alertView showAnimated:YES completionHandler:nil];
        }
    }
}

#pragma mark - Keyboard Events

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardFrame = [[[notification userInfo] valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardAppearingDuration = [[[notification userInfo] valueForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGPoint scrollOffset = CGPointMake(self.mainScrollView.contentOffset.x, keyboardFrame.size.height - self.chatMessageInput.frame.size.height + 1);

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:keyboardAppearingDuration animations:^{
        __strong typeof(weakSelf) self = weakSelf;
        self.mainScrollView.contentOffset = scrollOffset;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    CGFloat keyboardAppearingDuration = [[[notification userInfo] valueForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGPoint offset = CGPointZero;
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:keyboardAppearingDuration animations:^{
        __strong typeof(weakSelf) self = weakSelf;
        self.mainScrollView.contentOffset = offset;
    }];
}

#pragma mark - AMWordViewDelegate

- (void)wordDeleteButtonPressed:(AMChatMessageModel*)message {
    
}

#pragma mark - AMChatTextInputViewDelegate

- (void)needToAddToCategory:(NSString*)message {
    __weak typeof(self) weakSelf = self;
    LGAlertView *alertView = [[LGAlertView alloc] initWithTextFieldsAndTitle:@"Add word"
                                                                     message:@"Type name of word category"
                                                          numberOfTextFields:1
                                                      textFieldsSetupHandler:nil
                                                                buttonTitles:@[@"Add"]
                                                           cancelButtonTitle:@"Cancel"
                                                      destructiveButtonTitle:nil
                                                               actionHandler:^(LGAlertView *alertView, NSString *title, NSUInteger index) {
                                                                   __strong typeof(weakSelf) self = weakSelf;
                                                                   
                                                                   UITextField *textField = [alertView.textFieldsArray objectAtIndex:index];
                                                                   if ([self isTextEmpty:textField.text] == YES
                                                                       || [self isTextEmpty:message] == YES) {
                                                                       return;
                                                                   }
                                                                   
                                                                   self.temporaryMsg = [[AMChatMessageModel alloc] init];
                                                                   self.temporaryMsg.chatMessageTimestamp = [[NSDate date] timeIntervalSince1970];
                                                                   self.temporaryMsg.chatMessage = message;
                                                                   self.temporaryMsg.conversationUniqId = self.conversationUniqId;
                                                                   
                                                                   NSPredicate *predicate = [NSPredicate predicateWithFormat:@"categoryTitle == %@", textField.text];
                                                                   RLMResults *resultsConversation = [AMCategoryModel objectsWithPredicate:predicate];
                                                                   AMCategoryModel *category = nil;
                                                                   
                                                                   if (resultsConversation.count == 0) {
                                                                       category = [[AMCategoryModel alloc] init];
                                                                       category.categoryTitle = textField.text;
                                                                       category.categoryTimestamp = [[NSDate date] timeIntervalSince1970];
                                                                       category.categoryUniqId = [NSUUID UUID].UUIDString;
                                                                       
                                                                       
                                                                       RLMRealm *realm = [RLMRealm defaultRealm];
                                                                       [realm beginWriteTransaction];
                                                                       [realm addObject:category];
                                                                       [realm commitWriteTransaction];
                                                                   } else {
                                                                       category = (AMCategoryModel*)[resultsConversation objectAtIndex:0];
                                                                   }
                                                                   self.temporaryMsg.categoryUniqId = category.categoryUniqId;
                                                               }
                                                               cancelHandler:nil
                                                          destructiveHandler:nil];
    alertView.cancelOnTouch = NO;
    
    [alertView showAnimated:YES completionHandler:nil];
}

- (void)needToSendMessage:(NSString*)message {
    if ([self isTextEmpty:message] == YES) {
        return;
    }
    
    AMChatMessageModel *msg = nil;
    if ([self.temporaryMsg.chatMessage isEqualToString:message] == YES) {
        msg = self.temporaryMsg;
        self.temporaryMsg = nil;
    } else {
        msg = [[AMChatMessageModel alloc] init];
        
        msg.chatMessage = message;
        msg.conversationUniqId = self.conversationUniqId;
        msg.chatMessageTimestamp = [[NSDate date] timeIntervalSince1970];
    }
    
    [self.chatMessages insertObject:msg atIndex:0];
    [self.chatTable insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:YES];
    
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [realm addObject:msg];
    [realm commitWriteTransaction];
}

#pragma mark - UICollectionViewDelegate

#pragma mark - UICollectionViewDataSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.wordsForCategory.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AMWordCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[AMWordCollectionViewCell cellId]
                                                                               forIndexPath:indexPath];
    cell.word = [self.wordsForCategory objectAtIndex:indexPath.item];
    
    return cell;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    AMCategoryModel *categoryModel = [self.categoryQueryResult objectAtIndex:row];
    
    return categoryModel.categoryTitle;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.categoryQueryResult.count;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.chatMessages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier forIndexPath:indexPath];
    
    cell.textLabel.text = [self.chatMessages objectAtIndex:indexPath.row].chatMessage;
    cell.transform = CGAffineTransformMakeRotation(M_PI);
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    
    return cell;
}

@end
