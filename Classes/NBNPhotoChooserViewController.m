#import "NBNPhotoChooserViewController.h"
#import "NBNAssetCell.h"
#import "NBNPhotoMiner.h"
#import "NBNImageCaptureCell.h"
#import "NBNTransitioningDelegate.h"

@interface NBNPhotoChooserViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic) NSArray *images;
@property (nonatomic, weak) id<NBNPhotoChooserViewControllerDelegate> delegate;
@property (nonatomic) NBNImageCaptureCell *captureCell;
@property (nonatomic) NBNTransitioningDelegate *transitioningDelegate;
@property (nonatomic) UIImagePickerController *imagePickerController;
@property (nonatomic) UIBarButtonItem *cancelButton;

@end

@implementation NBNPhotoChooserViewController

- (id)initWithDelegate:(id<NBNPhotoChooserViewControllerDelegate>)delegate {
    self = [super init];

    if (self) {
        _delegate = delegate;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupCollectionView];
    [self setupNavigationBar];
    [self registerCellTypes];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadDataSource];
}

- (void)reloadDataSource {
    NBNPhotoMiner *photoMiner = [[NBNPhotoMiner alloc] init];
    [photoMiner getAllPicturesCompletion:^(NSArray *images) {
        self.images = [[NSArray alloc] initWithArray:images];
        [self.collectionView reloadData];
        [self scrollToBottom:NO];
    }];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame
                                             collectionViewLayout:flowLayout];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.view addSubview:self.collectionView];
}

- (void)setupNavigationBar {
    self.cancelButton = [[UIBarButtonItem alloc] initWithTitle:self.cancelButtonTitle
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = self.cancelButton;
}

- (void)registerCellTypes {
    [NBNAssetCell registerIn:self.collectionView];
    [NBNImageCaptureCell registerIn:self.collectionView];
}

- (void)cancel:(id)sender {
    if ([self.delegate respondsToSelector:@selector(photoChooserDidCancel:)]) {
        [self.delegate photoChooserDidCancel:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)isCaptureCellInIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == self.images.count && [self hasCamera]) {
        return YES;
    }

    return NO;
}

- (BOOL)hasCamera {
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.images.count + ([self hasCamera] ? 1 : 0);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    if ([self isCaptureCellInIndexPath:indexPath]) {
        return [self imageCaptureCellForCollectionView:collectionView atIndex:indexPath];
    } else {
        return [self assetCellForCollectionView:collectionView atIndex:indexPath];
    }
}

- (UICollectionViewCell *)assetCellForCollectionView:(UICollectionView *)collectionView
                                             atIndex:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = [NBNAssetCell reuserIdentifier];
    NBNAssetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier
                                                                   forIndexPath:indexPath];
    NSDictionary *dict = [self.images objectAtIndex:indexPath.row];
    UIImage *asset = dict[NBNPhotoMinerKeyImage];
    [cell configureWithAsset:asset];

    return cell;
}

- (UICollectionViewCell *)imageCaptureCellForCollectionView:(UICollectionView *)collectionView
                                                    atIndex:(NSIndexPath *)indexPath {

    NSString *CellIdentifier = [NBNImageCaptureCell reuserIdentifier];
    self.captureCell = [self.collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier
                                                                               forIndexPath:indexPath];

    [self.captureCell configureCell];
    return self.captureCell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [NBNAssetCell size];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isCaptureCellInIndexPath:indexPath]) {
        [self didChooseImagePicker];
    } else {
        [self didChooseImage:self.images[indexPath.row]];
    }
}

- (void)didChooseImage:(NSDictionary *)dictionary {
    if ([self.delegate respondsToSelector:@selector(photoChooserController:didChooseImage:)]) {
        [NBNPhotoMiner imageFromDictionary:dictionary block:^(UIImage *fullResolutionImage) {
            [self.delegate photoChooserController:self didChooseImage:fullResolutionImage];
        }];
    } else {
         NSAssert(NO, @"Delegate didChooseImage: has to be implemented");
    }
    if ([self.imagePickerController presentingViewController]) {
        [self.imagePickerController dismissViewControllerAnimated:NO completion:^{
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }

}

#pragma mark - Image Preview choosing

- (void)didChooseImagePicker {
    [self.captureCell removeSubviews];

    self.imagePickerController = [[UIImagePickerController alloc] init];
    self.imagePickerController.delegate = self;
    self.imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.imagePickerController.showsCameraControls = YES;
    if ([self.imagePickerController respondsToSelector:@selector(transitioningDelegate)]) {
        self.transitioningDelegate = [[NBNTransitioningDelegate alloc] init];
        self.imagePickerController.transitioningDelegate = self.transitioningDelegate;
    }

    [self.navigationController presentViewController:self.imagePickerController animated:YES completion:nil];
}

- (void)prepareForFullScreen {
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)prepareForImagePreviews {
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

- (void)toggleCapturingMode {
    [self.collectionView reloadData];
    [self scrollToBottom:NO];
    [self.collectionView setScrollEnabled:!self.collectionView.isScrollEnabled];
}

- (void)scrollToBottom:(BOOL)animated {
    NSInteger count = [self collectionView:self.collectionView numberOfItemsInSection:0];
    if (count == 0) {
        return;
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:count-1 inSection:0];
    [self.collectionView scrollToItemAtIndexPath:indexPath
                                atScrollPosition:UICollectionViewScrollPositionBottom
                                        animated:animated];
}

#pragma mark - Setter

- (void)setNavigationBarTitle:(NSString *)navigationBarTitle {
    _navigationBarTitle = navigationBarTitle;
    self.title = navigationBarTitle;
}

- (void)setCancelButtonTitle:(NSString *)cancelButtonTitle {
    _cancelButtonTitle = cancelButtonTitle;
    self.cancelButton.title = cancelButtonTitle;
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    picker.showsCameraControls = NO;
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [NBNPhotoMiner lastImageWithCompletion:^(NSDictionary *dict) {
        [self didChooseImage:dict];
    }];
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

@end
