// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: camel_case_types

import 'dart:typed_data';

import 'package:objectbox/flatbuffers/flat_buffers.dart' as fb;
import 'package:objectbox/internal.dart'; // generated code can access "internal" functionality
import 'package:objectbox/objectbox.dart';
import 'package:objectbox_flutter_libs/objectbox_flutter_libs.dart';

import 'repository/models/io/attachment.dart';
import 'repository/models/io/chat.dart';
import 'repository/models/io/fcm_data.dart';
import 'repository/models/io/handle.dart';
import 'repository/models/io/message.dart';
import 'repository/models/io/scheduled.dart';
import 'repository/models/io/theme_entry.dart';
import 'repository/models/io/theme_object.dart';

export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file

final _entities = <ModelEntity>[
  ModelEntity(
      id: const IdUid(1, 2065429213543838585),
      name: 'Attachment',
      lastPropertyId: const IdUid(18, 4627777114429677812),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 1511554263230297197),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 2178477183992316459),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 895699641082029197),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(1, 1274831956298930522)),
        ModelProperty(
            id: const IdUid(4, 6047065591027683672),
            name: 'uti',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 8856072667843358452),
            name: 'mimeType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 2957720185959973011),
            name: 'transferState',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 2217746424870068461),
            name: 'isOutgoing',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 5943814485048944977),
            name: 'transferName',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 2227654525168892418),
            name: 'totalBytes',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 226618350909080419),
            name: 'isSticker',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 7216531465575414151),
            name: 'hideAttachment',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 8776591297555015451),
            name: 'blurhash',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 171869175523313868),
            name: 'height',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 2450795986531805384),
            name: 'width',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 5516087858141459065),
            name: 'bytes',
            type: 23,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 396659320299238462),
            name: 'webUrl',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(17, 5777776419087046056),
            name: 'messageId',
            type: 11,
            flags: 520,
            indexId: const IdUid(8, 2010461783272999439),
            relationTarget: 'Message'),
        ModelProperty(
            id: const IdUid(18, 4627777114429677812),
            name: 'dbMetadata',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(3, 9017250848141753702),
      name: 'Chat',
      lastPropertyId: const IdUid(21, 55197157095191277),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 297833828287439140),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 8252364803444354563),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 318412581013308394),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(2, 4712841847590882583)),
        ModelProperty(
            id: const IdUid(4, 4143511131199296878),
            name: 'style',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 9099706644901956287),
            name: 'chatIdentifier',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 9117376896883192460),
            name: 'isArchived',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 172817608355620424),
            name: 'isFiltered',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 2937507201037513710),
            name: 'muteType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 3354772670242853270),
            name: 'muteArgs',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 3734639758158862923),
            name: 'isPinned',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 2937716363156975856),
            name: 'hasUnreadMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 526293286661780207),
            name: 'latestMessageDate',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 4983193271800913860),
            name: 'latestMessageText',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 130925169208448361),
            name: 'fakeLatestMessageText',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 4266631519717388837),
            name: 'title',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 1181486482872028222),
            name: 'displayName',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(18, 3666111733726849006),
            name: 'customAvatarPath',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(19, 4234470006262207812),
            name: 'pinIndex',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(20, 2695161584801983484),
            name: 'autoSendReadReceipts',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(21, 55197157095191277),
            name: 'autoSendTypingIndicators',
            type: 1,
            flags: 0)
      ],
      relations: <ModelRelation>[
        ModelRelation(
            id: const IdUid(1, 7492985733214117623),
            name: 'handles',
            targetId: const IdUid(7, 1716592500251888002))
      ],
      backlinks: <ModelBacklink>[
        ModelBacklink(name: 'messages', srcEntity: 'Message', srcField: 'chat')
      ]),
  ModelEntity(
      id: const IdUid(6, 5390756932993878582),
      name: 'FCMData',
      lastPropertyId: const IdUid(7, 4724783625435560776),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 843767696595301490),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 4393840145875077709),
            name: 'projectID',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 7264245173656870052),
            name: 'storageBucket',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 3998672972942379984),
            name: 'apiKey',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 3295687739104688136),
            name: 'firebaseURL',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 8856592728926530171),
            name: 'clientID',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 4724783625435560776),
            name: 'applicationID',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(7, 1716592500251888002),
      name: 'Handle',
      lastPropertyId: const IdUid(7, 549408491521049277),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 683096758365457558),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 191994702917313644),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 2544513926695389102),
            name: 'address',
            type: 9,
            flags: 2080,
            indexId: const IdUid(3, 9132680703832217528)),
        ModelProperty(
            id: const IdUid(4, 8884526609844353946),
            name: 'country',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 3522974353771163433),
            name: 'color',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 57094839621772204),
            name: 'defaultPhone',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 549408491521049277),
            name: 'uncanonicalizedId',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(10, 7380334062783734091),
      name: 'ThemeEntry',
      lastPropertyId: const IdUid(8, 4809686302323910258),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 3364349183457626105),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 378260260370164099),
            name: 'themeId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 1711484628702995090),
            name: 'name',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 5820153989252425651),
            name: 'isFont',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 357044983311472123),
            name: 'fontSize',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 205399809771216750),
            name: 'dbColor',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 2424613981822393823),
            name: 'fontWeight',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 4809686302323910258),
            name: 'themeObjectId',
            type: 11,
            flags: 520,
            indexId: const IdUid(10, 9160679880876705382),
            relationTarget: 'ThemeObject')
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(13, 4148278195232901830),
      name: 'Message',
      lastPropertyId: const IdUid(39, 1372898255926257108),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 2871568629586737055),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 1582361484724166619),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 8669586978455730639),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(6, 4451778671291639024)),
        ModelProperty(
            id: const IdUid(4, 9142895361605464091),
            name: 'handleId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 7874018753129857845),
            name: 'otherHandle',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 4547092920121180060),
            name: 'text',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 2233028199063732172),
            name: 'subject',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 3994409138392851632),
            name: 'country',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 5531207057664871058),
            name: 'dateCreated',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 3811604236432549817),
            name: 'dateRead',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 7356445736232735146),
            name: 'dateDelivered',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 626638148258506930),
            name: 'isFromMe',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 6839394073781850549),
            name: 'isDelayed',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 4584830839955803056),
            name: 'isAutoReply',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 5300777612659164835),
            name: 'isSystemMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 7579043230224812288),
            name: 'isServiceMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(17, 5309991997782167547),
            name: 'isForward',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(18, 6035615005231958928),
            name: 'isArchived',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(19, 5938275663538454436),
            name: 'hasDdResults',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(20, 457159365740007120),
            name: 'cacheRoomnames',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(21, 6085502636952418888),
            name: 'isAudioMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(22, 8082781591108942969),
            name: 'datePlayed',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(23, 7621327072355688575),
            name: 'itemType',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(24, 7649146516477763838),
            name: 'groupTitle',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(25, 1515848557190125128),
            name: 'groupActionType',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(26, 7378813296315172429),
            name: 'isExpired',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(27, 4765948580516232913),
            name: 'balloonBundleId',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(28, 8696985708980146227),
            name: 'associatedMessageGuid',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(29, 574575341112766208),
            name: 'associatedMessageType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(30, 7125401610778464945),
            name: 'expressiveSendStyleId',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(31, 7968765094195569385),
            name: 'timeExpressiveSendStyleId',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(32, 397296906153054772),
            name: 'hasAttachments',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(33, 3092611940313786692),
            name: 'hasReactions',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(34, 3672248506437712660),
            name: 'dateDeleted',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(35, 5022296267274326910),
            name: 'threadOriginatorGuid',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(36, 2742958821028567046),
            name: 'threadOriginatorPart',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(37, 5359949882738167432),
            name: 'bigEmoji',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(38, 2993306046047010488),
            name: 'error',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(39, 1372898255926257108),
            name: 'chatId',
            type: 11,
            flags: 520,
            indexId: const IdUid(9, 1947853053588120767),
            relationTarget: 'Chat')
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[
        ModelBacklink(
            name: 'dbAttachments', srcEntity: 'Attachment', srcField: 'message')
      ]),
  ModelEntity(
      id: const IdUid(14, 4579555475244243263),
      name: 'ScheduledMessage',
      lastPropertyId: const IdUid(5, 696004914151488398),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 4810718806330671770),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 8558367758823185430),
            name: 'chatGuid',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 7997144491374144435),
            name: 'message',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 1278586999912993922),
            name: 'epochTime',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 696004914151488398),
            name: 'completed',
            type: 1,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(15, 7753273527865539946),
      name: 'ThemeObject',
      lastPropertyId: const IdUid(7, 7718171125722310355),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 7682268131019867778),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 3805851416487185429),
            name: 'name',
            type: 9,
            flags: 2080,
            indexId: const IdUid(7, 6926665461572101158)),
        ModelProperty(
            id: const IdUid(3, 621312794123477095),
            name: 'selectedLightTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 2380808371075786065),
            name: 'selectedDarkTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 7474338997382293502),
            name: 'gradientBg',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 7459499326275659791),
            name: 'previousLightTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 7718171125722310355),
            name: 'previousDarkTheme',
            type: 1,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[
        ModelBacklink(
            name: 'themeEntries',
            srcEntity: 'ThemeEntry',
            srcField: 'themeObject')
      ])
];

/// Open an ObjectBox store with the model declared in this file.
Future<Store> openStore(
        {String? directory,
        int? maxDBSizeInKB,
        int? fileMode,
        int? maxReaders,
        bool queriesCaseSensitiveDefault = true,
        String? macosApplicationGroup}) async =>
    Store(getObjectBoxModel(),
        directory: directory ?? (await defaultStoreDirectory()).path,
        maxDBSizeInKB: maxDBSizeInKB,
        fileMode: fileMode,
        maxReaders: maxReaders,
        queriesCaseSensitiveDefault: queriesCaseSensitiveDefault,
        macosApplicationGroup: macosApplicationGroup);

/// ObjectBox model definition, pass it to [Store] - Store(getObjectBoxModel())
ModelDefinition getObjectBoxModel() {
  final model = ModelInfo(
      entities: _entities,
      lastEntityId: const IdUid(15, 7753273527865539946),
      lastIndexId: const IdUid(10, 9160679880876705382),
      lastRelationId: const IdUid(1, 7492985733214117623),
      lastSequenceId: const IdUid(0, 0),
      retiredEntityUids: const [
        7018417362319461469,
        2687525031757751054,
        1550674322389882817,
        1619417403499629985,
        4450451951397945314,
        1700370751061310153,
        3483028772414651169
      ],
      retiredIndexUids: const [],
      retiredPropertyUids: const [
        8075530627827069587,
        614139107975861462,
        4854433937459051257,
        5895852794473158582,
        3012867958425492030,
        7948534483488402365,
        7283017531024613481,
        6884032144126638879,
        6176853844548763600,
        9009878668681532753,
        7709208038424465489,
        3701890428713468427,
        735091670169932122,
        3235490937430157681,
        8126854405033462697,
        82657294837234349,
        8117526523647192200,
        8413228078295213488,
        6626097234365517692,
        939052079357746566,
        3171806281750931518,
        4464802064429422611,
        5542585324402061600,
        572939669859263693,
        3185617998247778963,
        769751664576031863,
        4077882089992206144,
        7238968990385881383,
        2316337434845256835,
        3331740086129339824,
        4741144250901643688,
        1646799728535719055,
        2482744653836740926,
        3558704390717166171,
        6156393125011218685,
        861137718943970360,
        4613854641642738901,
        5956431335972854454,
        8252934173466443273,
        7658149783933949012,
        7323923293952799044,
        115725376021487478,
        8802290647274083834,
        5487740941825196608,
        2406258303326474883,
        245348312617052981,
        3858153704624052397,
        63810393639568631,
        977456607049558352,
        2275379924137725049,
        6032584536718919119,
        7725198227526963956,
        4236934751716676271,
        8224006478743498888,
        7392117204304535224,
        5590979280237537790,
        4510870919779209192,
        5203631054946486128,
        2649653758394363860,
        1439376349402210172,
        8308083337629235136
      ],
      retiredRelationUids: const [],
      modelVersion: 5,
      modelVersionParserMinimum: 5,
      version: 1);

  final bindings = <Type, EntityDefinition>{
    Attachment: EntityDefinition<Attachment>(
        model: _entities[0],
        toOneRelations: (Attachment object) => [object.message],
        toManyRelations: (Attachment object) => {},
        getId: (Attachment object) => object.id,
        setId: (Attachment object, int id) {
          object.id = id;
        },
        objectToFB: (Attachment object, fb.Builder fbb) {
          final guidOffset =
              object.guid == null ? null : fbb.writeString(object.guid!);
          final utiOffset =
              object.uti == null ? null : fbb.writeString(object.uti!);
          final mimeTypeOffset = object.mimeType == null
              ? null
              : fbb.writeString(object.mimeType!);
          final transferStateOffset = object.transferState == null
              ? null
              : fbb.writeString(object.transferState!);
          final transferNameOffset = object.transferName == null
              ? null
              : fbb.writeString(object.transferName!);
          final blurhashOffset = object.blurhash == null
              ? null
              : fbb.writeString(object.blurhash!);
          final bytesOffset =
              object.bytes == null ? null : fbb.writeListInt8(object.bytes!);
          final webUrlOffset =
              object.webUrl == null ? null : fbb.writeString(object.webUrl!);
          final dbMetadataOffset = object.dbMetadata == null
              ? null
              : fbb.writeString(object.dbMetadata!);
          fbb.startTable(19);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.originalROWID);
          fbb.addOffset(2, guidOffset);
          fbb.addOffset(3, utiOffset);
          fbb.addOffset(4, mimeTypeOffset);
          fbb.addOffset(5, transferStateOffset);
          fbb.addBool(6, object.isOutgoing);
          fbb.addOffset(7, transferNameOffset);
          fbb.addInt64(8, object.totalBytes);
          fbb.addBool(9, object.isSticker);
          fbb.addBool(10, object.hideAttachment);
          fbb.addOffset(11, blurhashOffset);
          fbb.addInt64(12, object.height);
          fbb.addInt64(13, object.width);
          fbb.addOffset(14, bytesOffset);
          fbb.addOffset(15, webUrlOffset);
          fbb.addInt64(16, object.message.targetId);
          fbb.addOffset(17, dbMetadataOffset);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final bytesValue = const fb.ListReader<int>(fb.Int8Reader())
              .vTableGetNullable(buffer, rootOffset, 32);
          final object = Attachment(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              originalROWID: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              guid: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              uti: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              mimeType: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              transferState: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              isOutgoing: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 16),
              transferName: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 18),
              totalBytes: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 20),
              isSticker: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 22),
              hideAttachment: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 24),
              blurhash:
                  const fb.StringReader().vTableGetNullable(buffer, rootOffset, 26),
              height: const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 28),
              width: const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 30),
              bytes: bytesValue == null ? null : Uint8List.fromList(bytesValue),
              webUrl: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 34))
            ..dbMetadata = const fb.StringReader().vTableGetNullable(buffer, rootOffset, 38);
          object.message.targetId =
              const fb.Int64Reader().vTableGet(buffer, rootOffset, 36, 0);
          object.message.attach(store);
          return object;
        }),
    Chat: EntityDefinition<Chat>(
        model: _entities[1],
        toOneRelations: (Chat object) => [],
        toManyRelations: (Chat object) => {
              RelInfo<Chat>.toMany(1, object.id!): object.handles,
              RelInfo<Message>.toOneBacklink(
                      39, object.id!, (Message srcObject) => srcObject.chat):
                  object.messages
            },
        getId: (Chat object) => object.id,
        setId: (Chat object, int id) {
          object.id = id;
        },
        objectToFB: (Chat object, fb.Builder fbb) {
          final guidOffset = fbb.writeString(object.guid);
          final chatIdentifierOffset = object.chatIdentifier == null
              ? null
              : fbb.writeString(object.chatIdentifier!);
          final muteTypeOffset = object.muteType == null
              ? null
              : fbb.writeString(object.muteType!);
          final muteArgsOffset = object.muteArgs == null
              ? null
              : fbb.writeString(object.muteArgs!);
          final latestMessageTextOffset = object.latestMessageText == null
              ? null
              : fbb.writeString(object.latestMessageText!);
          final fakeLatestMessageTextOffset =
              object.fakeLatestMessageText == null
                  ? null
                  : fbb.writeString(object.fakeLatestMessageText!);
          final titleOffset =
              object.title == null ? null : fbb.writeString(object.title!);
          final displayNameOffset = object.displayName == null
              ? null
              : fbb.writeString(object.displayName!);
          final customAvatarPathOffset = object.customAvatarPath == null
              ? null
              : fbb.writeString(object.customAvatarPath!);
          fbb.startTable(22);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.originalROWID);
          fbb.addOffset(2, guidOffset);
          fbb.addInt64(3, object.style);
          fbb.addOffset(4, chatIdentifierOffset);
          fbb.addBool(5, object.isArchived);
          fbb.addBool(6, object.isFiltered);
          fbb.addOffset(7, muteTypeOffset);
          fbb.addOffset(8, muteArgsOffset);
          fbb.addBool(9, object.isPinned);
          fbb.addBool(10, object.hasUnreadMessage);
          fbb.addInt64(11, object.latestMessageDate?.millisecondsSinceEpoch);
          fbb.addOffset(12, latestMessageTextOffset);
          fbb.addOffset(13, fakeLatestMessageTextOffset);
          fbb.addOffset(14, titleOffset);
          fbb.addOffset(15, displayNameOffset);
          fbb.addOffset(17, customAvatarPathOffset);
          fbb.addInt64(18, object.pinIndex);
          fbb.addBool(19, object.autoSendReadReceipts);
          fbb.addBool(20, object.autoSendTypingIndicators);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final latestMessageDateValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 26);
          final object = Chat(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              originalROWID: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              guid:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''),
              style: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              chatIdentifier: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              isArchived: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              isFiltered: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 16),
              isPinned: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 22),
              muteType: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 18),
              muteArgs: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 20),
              hasUnreadMessage: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 24),
              displayName: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 34),
              latestMessageDate: latestMessageDateValue == null ? null : DateTime.fromMillisecondsSinceEpoch(latestMessageDateValue),
              latestMessageText: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 28),
              fakeLatestMessageText: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 30),
              autoSendReadReceipts: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 42),
              autoSendTypingIndicators: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 44))
            ..title = const fb.StringReader()
                .vTableGetNullable(buffer, rootOffset, 32)
            ..customAvatarPath = const fb.StringReader()
                .vTableGetNullable(buffer, rootOffset, 38)
            ..pinIndex = const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 40);
          InternalToManyAccess.setRelInfo(object.handles, store,
              RelInfo<Chat>.toMany(1, object.id!), store.box<Chat>());
          InternalToManyAccess.setRelInfo(
              object.messages,
              store,
              RelInfo<Message>.toOneBacklink(
                  39, object.id!, (Message srcObject) => srcObject.chat),
              store.box<Chat>());
          return object;
        }),
    FCMData: EntityDefinition<FCMData>(
        model: _entities[2],
        toOneRelations: (FCMData object) => [],
        toManyRelations: (FCMData object) => {},
        getId: (FCMData object) => object.id,
        setId: (FCMData object, int id) {
          object.id = id;
        },
        objectToFB: (FCMData object, fb.Builder fbb) {
          final projectIDOffset = object.projectID == null
              ? null
              : fbb.writeString(object.projectID!);
          final storageBucketOffset = object.storageBucket == null
              ? null
              : fbb.writeString(object.storageBucket!);
          final apiKeyOffset =
              object.apiKey == null ? null : fbb.writeString(object.apiKey!);
          final firebaseURLOffset = object.firebaseURL == null
              ? null
              : fbb.writeString(object.firebaseURL!);
          final clientIDOffset = object.clientID == null
              ? null
              : fbb.writeString(object.clientID!);
          final applicationIDOffset = object.applicationID == null
              ? null
              : fbb.writeString(object.applicationID!);
          fbb.startTable(8);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addOffset(1, projectIDOffset);
          fbb.addOffset(2, storageBucketOffset);
          fbb.addOffset(3, apiKeyOffset);
          fbb.addOffset(4, firebaseURLOffset);
          fbb.addOffset(5, clientIDOffset);
          fbb.addOffset(6, applicationIDOffset);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = FCMData(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              projectID: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              storageBucket: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              apiKey: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              firebaseURL: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              clientID: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              applicationID: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 16));

          return object;
        }),
    Handle: EntityDefinition<Handle>(
        model: _entities[3],
        toOneRelations: (Handle object) => [],
        toManyRelations: (Handle object) => {},
        getId: (Handle object) => object.id,
        setId: (Handle object, int id) {
          object.id = id;
        },
        objectToFB: (Handle object, fb.Builder fbb) {
          final addressOffset = fbb.writeString(object.address);
          final countryOffset =
              object.country == null ? null : fbb.writeString(object.country!);
          final colorOffset =
              object.color == null ? null : fbb.writeString(object.color!);
          final defaultPhoneOffset = object.defaultPhone == null
              ? null
              : fbb.writeString(object.defaultPhone!);
          final uncanonicalizedIdOffset = object.uncanonicalizedId == null
              ? null
              : fbb.writeString(object.uncanonicalizedId!);
          fbb.startTable(8);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.originalROWID);
          fbb.addOffset(2, addressOffset);
          fbb.addOffset(3, countryOffset);
          fbb.addOffset(4, colorOffset);
          fbb.addOffset(5, defaultPhoneOffset);
          fbb.addOffset(6, uncanonicalizedIdOffset);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = Handle(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              originalROWID: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              address:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''),
              country: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              defaultPhone: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              uncanonicalizedId: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 16))
            ..color = const fb.StringReader()
                .vTableGetNullable(buffer, rootOffset, 12);

          return object;
        }),
    ThemeEntry: EntityDefinition<ThemeEntry>(
        model: _entities[4],
        toOneRelations: (ThemeEntry object) => [object.themeObject],
        toManyRelations: (ThemeEntry object) => {},
        getId: (ThemeEntry object) => object.id,
        setId: (ThemeEntry object, int id) {
          object.id = id;
        },
        objectToFB: (ThemeEntry object, fb.Builder fbb) {
          final nameOffset =
              object.name == null ? null : fbb.writeString(object.name!);
          final dbColorOffset =
              object.dbColor == null ? null : fbb.writeString(object.dbColor!);
          fbb.startTable(9);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.themeId);
          fbb.addOffset(2, nameOffset);
          fbb.addBool(3, object.isFont);
          fbb.addInt64(4, object.fontSize);
          fbb.addOffset(5, dbColorOffset);
          fbb.addInt64(6, object.fontWeight);
          fbb.addInt64(7, object.themeObject.targetId);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ThemeEntry(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              themeId: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              name: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              isFont: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              fontSize: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              fontWeight: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 16))
            ..dbColor = const fb.StringReader()
                .vTableGetNullable(buffer, rootOffset, 14);
          object.themeObject.targetId =
              const fb.Int64Reader().vTableGet(buffer, rootOffset, 18, 0);
          object.themeObject.attach(store);
          return object;
        }),
    Message: EntityDefinition<Message>(
        model: _entities[5],
        toOneRelations: (Message object) => [object.chat],
        toManyRelations: (Message object) => {
              RelInfo<Attachment>.toOneBacklink(17, object.id!,
                      (Attachment srcObject) => srcObject.message):
                  object.dbAttachments
            },
        getId: (Message object) => object.id,
        setId: (Message object, int id) {
          object.id = id;
        },
        objectToFB: (Message object, fb.Builder fbb) {
          final guidOffset =
              object.guid == null ? null : fbb.writeString(object.guid!);
          final textOffset =
              object.text == null ? null : fbb.writeString(object.text!);
          final subjectOffset =
              object.subject == null ? null : fbb.writeString(object.subject!);
          final countryOffset =
              object.country == null ? null : fbb.writeString(object.country!);
          final cacheRoomnamesOffset = object.cacheRoomnames == null
              ? null
              : fbb.writeString(object.cacheRoomnames!);
          final groupTitleOffset = object.groupTitle == null
              ? null
              : fbb.writeString(object.groupTitle!);
          final balloonBundleIdOffset = object.balloonBundleId == null
              ? null
              : fbb.writeString(object.balloonBundleId!);
          final associatedMessageGuidOffset =
              object.associatedMessageGuid == null
                  ? null
                  : fbb.writeString(object.associatedMessageGuid!);
          final associatedMessageTypeOffset =
              object.associatedMessageType == null
                  ? null
                  : fbb.writeString(object.associatedMessageType!);
          final expressiveSendStyleIdOffset =
              object.expressiveSendStyleId == null
                  ? null
                  : fbb.writeString(object.expressiveSendStyleId!);
          final threadOriginatorGuidOffset = object.threadOriginatorGuid == null
              ? null
              : fbb.writeString(object.threadOriginatorGuid!);
          final threadOriginatorPartOffset = object.threadOriginatorPart == null
              ? null
              : fbb.writeString(object.threadOriginatorPart!);
          fbb.startTable(40);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.originalROWID);
          fbb.addOffset(2, guidOffset);
          fbb.addInt64(3, object.handleId);
          fbb.addInt64(4, object.otherHandle);
          fbb.addOffset(5, textOffset);
          fbb.addOffset(6, subjectOffset);
          fbb.addOffset(7, countryOffset);
          fbb.addInt64(8, object.dateCreated?.millisecondsSinceEpoch);
          fbb.addInt64(9, object.dateRead?.millisecondsSinceEpoch);
          fbb.addInt64(10, object.dateDelivered?.millisecondsSinceEpoch);
          fbb.addBool(11, object.isFromMe);
          fbb.addBool(12, object.isDelayed);
          fbb.addBool(13, object.isAutoReply);
          fbb.addBool(14, object.isSystemMessage);
          fbb.addBool(15, object.isServiceMessage);
          fbb.addBool(16, object.isForward);
          fbb.addBool(17, object.isArchived);
          fbb.addBool(18, object.hasDdResults);
          fbb.addOffset(19, cacheRoomnamesOffset);
          fbb.addBool(20, object.isAudioMessage);
          fbb.addInt64(21, object.datePlayed?.millisecondsSinceEpoch);
          fbb.addInt64(22, object.itemType);
          fbb.addOffset(23, groupTitleOffset);
          fbb.addInt64(24, object.groupActionType);
          fbb.addBool(25, object.isExpired);
          fbb.addOffset(26, balloonBundleIdOffset);
          fbb.addOffset(27, associatedMessageGuidOffset);
          fbb.addOffset(28, associatedMessageTypeOffset);
          fbb.addOffset(29, expressiveSendStyleIdOffset);
          fbb.addInt64(
              30, object.timeExpressiveSendStyleId?.millisecondsSinceEpoch);
          fbb.addBool(31, object.hasAttachments);
          fbb.addBool(32, object.hasReactions);
          fbb.addInt64(33, object.dateDeleted?.millisecondsSinceEpoch);
          fbb.addOffset(34, threadOriginatorGuidOffset);
          fbb.addOffset(35, threadOriginatorPartOffset);
          fbb.addBool(36, object.bigEmoji);
          fbb.addInt64(37, object.error);
          fbb.addInt64(38, object.chat.targetId);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final dateCreatedValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 20);
          final dateReadValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 22);
          final dateDeliveredValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 24);
          final datePlayedValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 46);
          final timeExpressiveSendStyleIdValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 64);
          final dateDeletedValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 70);
          final object = Message(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              originalROWID: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              guid: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              handleId: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              otherHandle: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              text: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              subject: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 16),
              country: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 18),
              dateCreated: dateCreatedValue == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(dateCreatedValue),
              isFromMe: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 26),
              isDelayed: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 28),
              isAutoReply:
                  const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 30),
              isSystemMessage: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 32),
              isServiceMessage: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 34),
              isForward: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 36),
              isArchived: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 38),
              hasDdResults: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 40),
              cacheRoomnames: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 42),
              isAudioMessage: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 44),
              datePlayed: datePlayedValue == null ? null : DateTime.fromMillisecondsSinceEpoch(datePlayedValue),
              itemType: const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 48),
              groupTitle: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 50),
              groupActionType: const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 52),
              isExpired: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 54),
              balloonBundleId: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 56),
              associatedMessageGuid: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 58),
              associatedMessageType: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 60),
              expressiveSendStyleId: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 62),
              timeExpressiveSendStyleId: timeExpressiveSendStyleIdValue == null ? null : DateTime.fromMillisecondsSinceEpoch(timeExpressiveSendStyleIdValue),
              hasAttachments: const fb.BoolReader().vTableGet(buffer, rootOffset, 66, false),
              hasReactions: const fb.BoolReader().vTableGet(buffer, rootOffset, 68, false),
              dateDeleted: dateDeletedValue == null ? null : DateTime.fromMillisecondsSinceEpoch(dateDeletedValue),
              threadOriginatorGuid: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 72),
              threadOriginatorPart: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 74))
            ..dateRead = dateReadValue == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(dateReadValue)
            ..dateDelivered = dateDeliveredValue == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(dateDeliveredValue)
            ..bigEmoji =
                const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 76)
            ..error = const fb.Int64Reader().vTableGet(buffer, rootOffset, 78, 0);
          object.chat.targetId =
              const fb.Int64Reader().vTableGet(buffer, rootOffset, 80, 0);
          object.chat.attach(store);
          InternalToManyAccess.setRelInfo(
              object.dbAttachments,
              store,
              RelInfo<Attachment>.toOneBacklink(
                  17, object.id!, (Attachment srcObject) => srcObject.message),
              store.box<Message>());
          return object;
        }),
    ScheduledMessage: EntityDefinition<ScheduledMessage>(
        model: _entities[6],
        toOneRelations: (ScheduledMessage object) => [],
        toManyRelations: (ScheduledMessage object) => {},
        getId: (ScheduledMessage object) => object.id,
        setId: (ScheduledMessage object, int id) {
          object.id = id;
        },
        objectToFB: (ScheduledMessage object, fb.Builder fbb) {
          final chatGuidOffset = object.chatGuid == null
              ? null
              : fbb.writeString(object.chatGuid!);
          final messageOffset =
              object.message == null ? null : fbb.writeString(object.message!);
          fbb.startTable(6);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addOffset(1, chatGuidOffset);
          fbb.addOffset(2, messageOffset);
          fbb.addInt64(3, object.epochTime);
          fbb.addBool(4, object.completed);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ScheduledMessage(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              chatGuid: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              message: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              epochTime: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              completed: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 12));

          return object;
        }),
    ThemeObject: EntityDefinition<ThemeObject>(
        model: _entities[7],
        toOneRelations: (ThemeObject object) => [],
        toManyRelations: (ThemeObject object) => {
              RelInfo<ThemeEntry>.toOneBacklink(8, object.id!,
                      (ThemeEntry srcObject) => srcObject.themeObject):
                  object.themeEntries
            },
        getId: (ThemeObject object) => object.id,
        setId: (ThemeObject object, int id) {
          object.id = id;
        },
        objectToFB: (ThemeObject object, fb.Builder fbb) {
          final nameOffset =
              object.name == null ? null : fbb.writeString(object.name!);
          fbb.startTable(8);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addOffset(1, nameOffset);
          fbb.addBool(2, object.selectedLightTheme);
          fbb.addBool(3, object.selectedDarkTheme);
          fbb.addBool(4, object.gradientBg);
          fbb.addBool(5, object.previousLightTheme);
          fbb.addBool(6, object.previousDarkTheme);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ThemeObject(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              name: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              selectedLightTheme:
                  const fb.BoolReader().vTableGet(buffer, rootOffset, 8, false),
              selectedDarkTheme: const fb.BoolReader()
                  .vTableGet(buffer, rootOffset, 10, false),
              gradientBg: const fb.BoolReader()
                  .vTableGet(buffer, rootOffset, 12, false),
              previousLightTheme: const fb.BoolReader()
                  .vTableGet(buffer, rootOffset, 14, false),
              previousDarkTheme: const fb.BoolReader()
                  .vTableGet(buffer, rootOffset, 16, false));
          InternalToManyAccess.setRelInfo(
              object.themeEntries,
              store,
              RelInfo<ThemeEntry>.toOneBacklink(8, object.id!,
                  (ThemeEntry srcObject) => srcObject.themeObject),
              store.box<ThemeObject>());
          return object;
        })
  };

  return ModelDefinition(model, bindings);
}

/// [Attachment] entity fields to define ObjectBox queries.
class Attachment_ {
  /// see [Attachment.id]
  static final id =
      QueryIntegerProperty<Attachment>(_entities[0].properties[0]);

  /// see [Attachment.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Attachment>(_entities[0].properties[1]);

  /// see [Attachment.guid]
  static final guid =
      QueryStringProperty<Attachment>(_entities[0].properties[2]);

  /// see [Attachment.uti]
  static final uti =
      QueryStringProperty<Attachment>(_entities[0].properties[3]);

  /// see [Attachment.mimeType]
  static final mimeType =
      QueryStringProperty<Attachment>(_entities[0].properties[4]);

  /// see [Attachment.transferState]
  static final transferState =
      QueryStringProperty<Attachment>(_entities[0].properties[5]);

  /// see [Attachment.isOutgoing]
  static final isOutgoing =
      QueryBooleanProperty<Attachment>(_entities[0].properties[6]);

  /// see [Attachment.transferName]
  static final transferName =
      QueryStringProperty<Attachment>(_entities[0].properties[7]);

  /// see [Attachment.totalBytes]
  static final totalBytes =
      QueryIntegerProperty<Attachment>(_entities[0].properties[8]);

  /// see [Attachment.isSticker]
  static final isSticker =
      QueryBooleanProperty<Attachment>(_entities[0].properties[9]);

  /// see [Attachment.hideAttachment]
  static final hideAttachment =
      QueryBooleanProperty<Attachment>(_entities[0].properties[10]);

  /// see [Attachment.blurhash]
  static final blurhash =
      QueryStringProperty<Attachment>(_entities[0].properties[11]);

  /// see [Attachment.height]
  static final height =
      QueryIntegerProperty<Attachment>(_entities[0].properties[12]);

  /// see [Attachment.width]
  static final width =
      QueryIntegerProperty<Attachment>(_entities[0].properties[13]);

  /// see [Attachment.bytes]
  static final bytes =
      QueryByteVectorProperty<Attachment>(_entities[0].properties[14]);

  /// see [Attachment.webUrl]
  static final webUrl =
      QueryStringProperty<Attachment>(_entities[0].properties[15]);

  /// see [Attachment.message]
  static final message =
      QueryRelationToOne<Attachment, Message>(_entities[0].properties[16]);

  /// see [Attachment.dbMetadata]
  static final dbMetadata =
      QueryStringProperty<Attachment>(_entities[0].properties[17]);
}

/// [Chat] entity fields to define ObjectBox queries.
class Chat_ {
  /// see [Chat.id]
  static final id = QueryIntegerProperty<Chat>(_entities[1].properties[0]);

  /// see [Chat.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Chat>(_entities[1].properties[1]);

  /// see [Chat.guid]
  static final guid = QueryStringProperty<Chat>(_entities[1].properties[2]);

  /// see [Chat.style]
  static final style = QueryIntegerProperty<Chat>(_entities[1].properties[3]);

  /// see [Chat.chatIdentifier]
  static final chatIdentifier =
      QueryStringProperty<Chat>(_entities[1].properties[4]);

  /// see [Chat.isArchived]
  static final isArchived =
      QueryBooleanProperty<Chat>(_entities[1].properties[5]);

  /// see [Chat.isFiltered]
  static final isFiltered =
      QueryBooleanProperty<Chat>(_entities[1].properties[6]);

  /// see [Chat.muteType]
  static final muteType = QueryStringProperty<Chat>(_entities[1].properties[7]);

  /// see [Chat.muteArgs]
  static final muteArgs = QueryStringProperty<Chat>(_entities[1].properties[8]);

  /// see [Chat.isPinned]
  static final isPinned =
      QueryBooleanProperty<Chat>(_entities[1].properties[9]);

  /// see [Chat.hasUnreadMessage]
  static final hasUnreadMessage =
      QueryBooleanProperty<Chat>(_entities[1].properties[10]);

  /// see [Chat.latestMessageDate]
  static final latestMessageDate =
      QueryIntegerProperty<Chat>(_entities[1].properties[11]);

  /// see [Chat.latestMessageText]
  static final latestMessageText =
      QueryStringProperty<Chat>(_entities[1].properties[12]);

  /// see [Chat.fakeLatestMessageText]
  static final fakeLatestMessageText =
      QueryStringProperty<Chat>(_entities[1].properties[13]);

  /// see [Chat.title]
  static final title = QueryStringProperty<Chat>(_entities[1].properties[14]);

  /// see [Chat.displayName]
  static final displayName =
      QueryStringProperty<Chat>(_entities[1].properties[15]);

  /// see [Chat.customAvatarPath]
  static final customAvatarPath =
      QueryStringProperty<Chat>(_entities[1].properties[16]);

  /// see [Chat.pinIndex]
  static final pinIndex =
      QueryIntegerProperty<Chat>(_entities[1].properties[17]);

  /// see [Chat.autoSendReadReceipts]
  static final autoSendReadReceipts =
      QueryBooleanProperty<Chat>(_entities[1].properties[18]);

  /// see [Chat.autoSendTypingIndicators]
  static final autoSendTypingIndicators =
      QueryBooleanProperty<Chat>(_entities[1].properties[19]);

  /// see [Chat.handles]
  static final handles =
      QueryRelationToMany<Chat, Handle>(_entities[1].relations[0]);
}

/// [FCMData] entity fields to define ObjectBox queries.
class FCMData_ {
  /// see [FCMData.id]
  static final id = QueryIntegerProperty<FCMData>(_entities[2].properties[0]);

  /// see [FCMData.projectID]
  static final projectID =
      QueryStringProperty<FCMData>(_entities[2].properties[1]);

  /// see [FCMData.storageBucket]
  static final storageBucket =
      QueryStringProperty<FCMData>(_entities[2].properties[2]);

  /// see [FCMData.apiKey]
  static final apiKey =
      QueryStringProperty<FCMData>(_entities[2].properties[3]);

  /// see [FCMData.firebaseURL]
  static final firebaseURL =
      QueryStringProperty<FCMData>(_entities[2].properties[4]);

  /// see [FCMData.clientID]
  static final clientID =
      QueryStringProperty<FCMData>(_entities[2].properties[5]);

  /// see [FCMData.applicationID]
  static final applicationID =
      QueryStringProperty<FCMData>(_entities[2].properties[6]);
}

/// [Handle] entity fields to define ObjectBox queries.
class Handle_ {
  /// see [Handle.id]
  static final id = QueryIntegerProperty<Handle>(_entities[3].properties[0]);

  /// see [Handle.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Handle>(_entities[3].properties[1]);

  /// see [Handle.address]
  static final address =
      QueryStringProperty<Handle>(_entities[3].properties[2]);

  /// see [Handle.country]
  static final country =
      QueryStringProperty<Handle>(_entities[3].properties[3]);

  /// see [Handle.color]
  static final color = QueryStringProperty<Handle>(_entities[3].properties[4]);

  /// see [Handle.defaultPhone]
  static final defaultPhone =
      QueryStringProperty<Handle>(_entities[3].properties[5]);

  /// see [Handle.uncanonicalizedId]
  static final uncanonicalizedId =
      QueryStringProperty<Handle>(_entities[3].properties[6]);
}

/// [ThemeEntry] entity fields to define ObjectBox queries.
class ThemeEntry_ {
  /// see [ThemeEntry.id]
  static final id =
      QueryIntegerProperty<ThemeEntry>(_entities[4].properties[0]);

  /// see [ThemeEntry.themeId]
  static final themeId =
      QueryIntegerProperty<ThemeEntry>(_entities[4].properties[1]);

  /// see [ThemeEntry.name]
  static final name =
      QueryStringProperty<ThemeEntry>(_entities[4].properties[2]);

  /// see [ThemeEntry.isFont]
  static final isFont =
      QueryBooleanProperty<ThemeEntry>(_entities[4].properties[3]);

  /// see [ThemeEntry.fontSize]
  static final fontSize =
      QueryIntegerProperty<ThemeEntry>(_entities[4].properties[4]);

  /// see [ThemeEntry.dbColor]
  static final dbColor =
      QueryStringProperty<ThemeEntry>(_entities[4].properties[5]);

  /// see [ThemeEntry.fontWeight]
  static final fontWeight =
      QueryIntegerProperty<ThemeEntry>(_entities[4].properties[6]);

  /// see [ThemeEntry.themeObject]
  static final themeObject =
      QueryRelationToOne<ThemeEntry, ThemeObject>(_entities[4].properties[7]);
}

/// [Message] entity fields to define ObjectBox queries.
class Message_ {
  /// see [Message.id]
  static final id = QueryIntegerProperty<Message>(_entities[5].properties[0]);

  /// see [Message.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Message>(_entities[5].properties[1]);

  /// see [Message.guid]
  static final guid = QueryStringProperty<Message>(_entities[5].properties[2]);

  /// see [Message.handleId]
  static final handleId =
      QueryIntegerProperty<Message>(_entities[5].properties[3]);

  /// see [Message.otherHandle]
  static final otherHandle =
      QueryIntegerProperty<Message>(_entities[5].properties[4]);

  /// see [Message.text]
  static final text = QueryStringProperty<Message>(_entities[5].properties[5]);

  /// see [Message.subject]
  static final subject =
      QueryStringProperty<Message>(_entities[5].properties[6]);

  /// see [Message.country]
  static final country =
      QueryStringProperty<Message>(_entities[5].properties[7]);

  /// see [Message.dateCreated]
  static final dateCreated =
      QueryIntegerProperty<Message>(_entities[5].properties[8]);

  /// see [Message.dateRead]
  static final dateRead =
      QueryIntegerProperty<Message>(_entities[5].properties[9]);

  /// see [Message.dateDelivered]
  static final dateDelivered =
      QueryIntegerProperty<Message>(_entities[5].properties[10]);

  /// see [Message.isFromMe]
  static final isFromMe =
      QueryBooleanProperty<Message>(_entities[5].properties[11]);

  /// see [Message.isDelayed]
  static final isDelayed =
      QueryBooleanProperty<Message>(_entities[5].properties[12]);

  /// see [Message.isAutoReply]
  static final isAutoReply =
      QueryBooleanProperty<Message>(_entities[5].properties[13]);

  /// see [Message.isSystemMessage]
  static final isSystemMessage =
      QueryBooleanProperty<Message>(_entities[5].properties[14]);

  /// see [Message.isServiceMessage]
  static final isServiceMessage =
      QueryBooleanProperty<Message>(_entities[5].properties[15]);

  /// see [Message.isForward]
  static final isForward =
      QueryBooleanProperty<Message>(_entities[5].properties[16]);

  /// see [Message.isArchived]
  static final isArchived =
      QueryBooleanProperty<Message>(_entities[5].properties[17]);

  /// see [Message.hasDdResults]
  static final hasDdResults =
      QueryBooleanProperty<Message>(_entities[5].properties[18]);

  /// see [Message.cacheRoomnames]
  static final cacheRoomnames =
      QueryStringProperty<Message>(_entities[5].properties[19]);

  /// see [Message.isAudioMessage]
  static final isAudioMessage =
      QueryBooleanProperty<Message>(_entities[5].properties[20]);

  /// see [Message.datePlayed]
  static final datePlayed =
      QueryIntegerProperty<Message>(_entities[5].properties[21]);

  /// see [Message.itemType]
  static final itemType =
      QueryIntegerProperty<Message>(_entities[5].properties[22]);

  /// see [Message.groupTitle]
  static final groupTitle =
      QueryStringProperty<Message>(_entities[5].properties[23]);

  /// see [Message.groupActionType]
  static final groupActionType =
      QueryIntegerProperty<Message>(_entities[5].properties[24]);

  /// see [Message.isExpired]
  static final isExpired =
      QueryBooleanProperty<Message>(_entities[5].properties[25]);

  /// see [Message.balloonBundleId]
  static final balloonBundleId =
      QueryStringProperty<Message>(_entities[5].properties[26]);

  /// see [Message.associatedMessageGuid]
  static final associatedMessageGuid =
      QueryStringProperty<Message>(_entities[5].properties[27]);

  /// see [Message.associatedMessageType]
  static final associatedMessageType =
      QueryStringProperty<Message>(_entities[5].properties[28]);

  /// see [Message.expressiveSendStyleId]
  static final expressiveSendStyleId =
      QueryStringProperty<Message>(_entities[5].properties[29]);

  /// see [Message.timeExpressiveSendStyleId]
  static final timeExpressiveSendStyleId =
      QueryIntegerProperty<Message>(_entities[5].properties[30]);

  /// see [Message.hasAttachments]
  static final hasAttachments =
      QueryBooleanProperty<Message>(_entities[5].properties[31]);

  /// see [Message.hasReactions]
  static final hasReactions =
      QueryBooleanProperty<Message>(_entities[5].properties[32]);

  /// see [Message.dateDeleted]
  static final dateDeleted =
      QueryIntegerProperty<Message>(_entities[5].properties[33]);

  /// see [Message.threadOriginatorGuid]
  static final threadOriginatorGuid =
      QueryStringProperty<Message>(_entities[5].properties[34]);

  /// see [Message.threadOriginatorPart]
  static final threadOriginatorPart =
      QueryStringProperty<Message>(_entities[5].properties[35]);

  /// see [Message.bigEmoji]
  static final bigEmoji =
      QueryBooleanProperty<Message>(_entities[5].properties[36]);

  /// see [Message.error]
  static final error =
      QueryIntegerProperty<Message>(_entities[5].properties[37]);

  /// see [Message.chat]
  static final chat =
      QueryRelationToOne<Message, Chat>(_entities[5].properties[38]);
}

/// [ScheduledMessage] entity fields to define ObjectBox queries.
class ScheduledMessage_ {
  /// see [ScheduledMessage.id]
  static final id =
      QueryIntegerProperty<ScheduledMessage>(_entities[6].properties[0]);

  /// see [ScheduledMessage.chatGuid]
  static final chatGuid =
      QueryStringProperty<ScheduledMessage>(_entities[6].properties[1]);

  /// see [ScheduledMessage.message]
  static final message =
      QueryStringProperty<ScheduledMessage>(_entities[6].properties[2]);

  /// see [ScheduledMessage.epochTime]
  static final epochTime =
      QueryIntegerProperty<ScheduledMessage>(_entities[6].properties[3]);

  /// see [ScheduledMessage.completed]
  static final completed =
      QueryBooleanProperty<ScheduledMessage>(_entities[6].properties[4]);
}

/// [ThemeObject] entity fields to define ObjectBox queries.
class ThemeObject_ {
  /// see [ThemeObject.id]
  static final id =
      QueryIntegerProperty<ThemeObject>(_entities[7].properties[0]);

  /// see [ThemeObject.name]
  static final name =
      QueryStringProperty<ThemeObject>(_entities[7].properties[1]);

  /// see [ThemeObject.selectedLightTheme]
  static final selectedLightTheme =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[2]);

  /// see [ThemeObject.selectedDarkTheme]
  static final selectedDarkTheme =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[3]);

  /// see [ThemeObject.gradientBg]
  static final gradientBg =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[4]);

  /// see [ThemeObject.previousLightTheme]
  static final previousLightTheme =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[5]);

  /// see [ThemeObject.previousDarkTheme]
  static final previousDarkTheme =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[6]);
}
