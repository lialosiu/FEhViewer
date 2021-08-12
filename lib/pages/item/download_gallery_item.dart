import 'package:extended_image/extended_image.dart';
import 'package:fehviewer/common/controller/gallerycache_controller.dart';
import 'package:fehviewer/common/isolate_download/download_manager.dart';
import 'package:fehviewer/const/theme_colors.dart';
import 'package:fehviewer/models/gallery_cache.dart';
import 'package:fehviewer/network/gallery_request.dart';
import 'package:fehviewer/pages/tab/controller/download_view_controller.dart';
import 'package:fehviewer/route/navigator_util.dart';
import 'package:fehviewer/store/floor/entity/gallery_image_task.dart';
import 'package:fehviewer/store/floor/entity/gallery_task.dart';
import 'package:fehviewer/utils/logger.dart';
import 'package:fehviewer/widget/eh_cached_network_image.dart';
import 'package:fehviewer/widget/rating_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class DownloadGalleryItem extends GetView<DownloadViewController> {
  const DownloadGalleryItem({
    Key? key,
    required this.galleryTask,
    this.speed,
  }) : super(key: key);

  final GalleryTask galleryTask;
  final String? speed;

  @override
  Widget build(BuildContext context) {
    final DateTime date =
        DateTime.fromMillisecondsSinceEpoch(galleryTask.addTime ?? 0);
    final addTime = galleryTask.addTime != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(date)
        : null;

    final status = TaskStatus(galleryTask.status ?? 0);
    final _complete = status == TaskStatus.complete;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final List<GalleryImageTask> imageTasks =
            await controller.getImageTasks(galleryTask.gid);
        final GalleryTask? gTask = controller.galleryTaskMap[galleryTask.gid];
        if (gTask == null) {
          return;
        }

        final List<String> pics = imageTasks
            .where((element) =>
                element.filePath != null && element.filePath!.isNotEmpty)
            .map((e) => path.join(gTask.realDirPath ?? '', e.filePath ?? ''))
            .toList();

        final GalleryCache? _galleryCache = Get.find<GalleryCacheController>()
            .getGalleryCache('${galleryTask.gid}');
        final lastIndex = _galleryCache?.lastIndex ?? 0;

        NavigatorUtil.goGalleryViewPageFile(
            lastIndex, pics, '${galleryTask.gid}');
      },
      child: Container(
        padding: const EdgeInsets.only(top: 4, bottom: 4, left: 20, right: 16),
        height: 120,
        child: Row(
          children: [
            // 封面
            GestureDetector(
              child: _CoverImage(
                      filePath: galleryTask.coverImage != null
                          ? path.join(galleryTask.realDirPath ?? '',
                              galleryTask.coverImage)
                          : null,
                      url: galleryTask.coverUrl)
                  .paddingOnly(right: 8),
              onTap: () async {
                logger.v('${galleryTask.url} ');
                String? url = galleryTask.url;
                if (url == null) {
                  return;
                }
                if (!url.startsWith('http')) {
                  url = '${Api.getBaseUrl()}$url';
                }
                NavigatorUtil.goGalleryPage(url: url);
              },
            ),
            // 右侧
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    galleryTask.title,
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ).paddingSymmetric(vertical: 2),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    galleryTask.uploader ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CupertinoDynamicColor.resolve(
                                          CupertinoColors.secondaryLabel,
                                          context),
                                    ),
                                  ),
                                  const Spacer(),
                                  // 任务添加时间
                                  Text(
                                    addTime ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CupertinoDynamicColor.resolve(
                                          CupertinoColors.secondaryLabel,
                                          context),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // 进度条
                              if (!_complete)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (galleryTask.completCount ?? 0) /
                                        galleryTask.fileCount,
                                    backgroundColor:
                                        CupertinoDynamicColor.resolve(
                                            CupertinoColors.secondarySystemFill,
                                            context),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      CupertinoDynamicColor.resolve(
                                          CupertinoColors.activeBlue, context),
                                    ),
                                  ),
                                )
                              else
                                _buildRating(galleryTask.rating),
                              // 下载速度 下载进度
                              Row(
                                children: [
                                  if (!_complete)
                                    Text(
                                      speed != null ? '$speed/s' : '',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: CupertinoDynamicColor.resolve(
                                              CupertinoColors.secondaryLabel,
                                              context)),
                                    )
                                  else
                                    _buildCategory(galleryTask.category),
                                  const Spacer(),
                                  Text(
                                    _complete
                                        ? '${galleryTask.fileCount}'
                                        : '${galleryTask.completCount ?? 0}/${galleryTask.fileCount}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.secondaryLabel,
                                            context)),
                                  ),
                                  // 控制按钮
                                  _getIcon(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRating(double? rating) {
    if (rating == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
          child: StaticRatingBar(
            size: 16.0,
            rate: rating,
            radiusRatio: 1.5,
            colorLight: ThemeColors.colorRatingMap['ir'],
            colorDark: CupertinoDynamicColor.resolve(
                CupertinoColors.systemGrey3, Get.context!),
          ),
        ),
        Text(
          rating.toString(),
          style: TextStyle(
            fontSize: 11,
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemGrey, Get.context!),
          ),
        ),
      ],
    );
  }

  Widget _buildCategory(String? category) {
    final Color _colorCategory = CupertinoDynamicColor.resolve(
        ThemeColors.catColor[category ?? 'default'] ??
            CupertinoColors.systemBackground,
        Get.context!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
        color: _colorCategory,
        child: Text(
          category ?? '',
          style: const TextStyle(
            fontSize: 14,
            height: 1,
            color: CupertinoColors.white,
          ),
        ),
      ),
    );
  }

  Widget _getIcon() {
    final GalleryTask? _taskInfo = controller.galleryTaskMap[galleryTask.gid];
    const minSize = 30.0;
    const iconSize = 18.0;
    const buttonPadding = EdgeInsets.only(left: 8.0);

    final Map<TaskStatus, Widget> statusMap = {
      // 下载时，显示暂停按钮
      TaskStatus.running: CupertinoTheme(
        data: const CupertinoThemeData(primaryColor: CupertinoColors.systemRed),
        child: CupertinoButton(
          padding: buttonPadding,
          minSize: minSize,
          child: const Icon(
            FontAwesomeIcons.pause,
            size: iconSize,
          ),
          onPressed: () {
            controller.pauseGalleryDownload(_taskInfo?.gid);
          },
        ),
      ),
      // 完成时 按下无动作
      TaskStatus.complete: CupertinoTheme(
        data:
            const CupertinoThemeData(primaryColor: CupertinoColors.activeBlue),
        child: CupertinoButton(
          padding: buttonPadding,
          minSize: minSize,
          child: const Icon(
            FontAwesomeIcons.check,
            size: iconSize,
          ),
          onPressed: () {},
        ),
      ),
      // 暂停时 显示继续按钮。按下恢复任务
      TaskStatus.paused: CupertinoTheme(
        data:
            const CupertinoThemeData(primaryColor: CupertinoColors.activeGreen),
        child: CupertinoButton(
          padding: buttonPadding,
          minSize: minSize,
          child: const Icon(
            FontAwesomeIcons.play,
            size: iconSize,
          ),
          onPressed: () {
            controller.resumeGalleryDownload(_taskInfo?.gid);
          },
        ),
      ),
      // 失败时 显示重试按钮。按下重试任务
      TaskStatus.failed: CupertinoButton(
        padding: buttonPadding,
        minSize: minSize,
        child: const Icon(
          FontAwesomeIcons.play,
          size: iconSize,
        ),
        onPressed: () {
          controller.retryArchiverDownload(galleryTask.gid);
        },
      ),
      // 取消状态 显示重试按钮。按下重试任务
      TaskStatus.canceled: CupertinoButton(
        padding: buttonPadding,
        minSize: minSize,
        child: const Icon(
          FontAwesomeIcons.redo,
          size: iconSize,
        ),
        onPressed: () {
          controller.retryArchiverDownload(galleryTask.gid);
        },
      ).paddingSymmetric(),
      TaskStatus.enqueued: Container(
        width: minSize,
        height: minSize,
        child: const CupertinoActivityIndicator(
          radius: 12,
        ),
      ),
      TaskStatus.undefined: Container(
        width: minSize,
        height: minSize,
        child: const CupertinoActivityIndicator(
          radius: 12,
        ),
      ),
    };

    return statusMap[TaskStatus(galleryTask.status ?? 0)] ??
        const SizedBox(width: 40);
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    this.url,
    this.filePath,
    Key? key,
  }) : super(key: key);

  final String? filePath;
  final String? url;

  @override
  Widget build(BuildContext context) {
    logger.v('$filePath  $url');

    return Container(
      width: 70,
      decoration: BoxDecoration(
        boxShadow: [
          //阴影
          BoxShadow(
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemGrey5, Get.context!),
            blurRadius: 3,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: () {
          if (filePath != null) {
            return ExtendedImage.file(
              File(filePath!),
              fit: BoxFit.fitWidth,
            );
          } else if (url != null) {
            return EhCachedNetworkImage(
              imageUrl: url!,
            );
          } else {
            return const SizedBox.expand();
          }
        }(),
      ),
    );
  }
}