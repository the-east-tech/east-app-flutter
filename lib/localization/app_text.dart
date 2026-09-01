import 'app_language.dart';
import '../models/translation_models.dart';

class AppText {
  final AppLanguage language;
  final Map<String, String> contentTranslations;

  const AppText(
    this.language, {
    this.contentTranslations = const <String, String>{},
  });

  String t(String key) {
    switch (language) {
      case AppLanguage.english:
        return key;
      case AppLanguage.myanmar:
        return _translate(key, _myanmar);
      case AppLanguage.chinese:
        return _translate(key, _chinese);
    }
  }

  String _translate(String key, Map<String, String> translations) {
    final direct = translations[key];
    if (direct != null) return direct;

    if (key.endsWith(' required')) {
      final label = key.substring(0, key.length - ' required'.length);
      final translatedLabel = translations[label] ?? label;
      return language == AppLanguage.chinese
          ? '$translatedLabel为必填项'
          : '$translatedLabel ဖြည့်ရန်လိုအပ်သည်';
    }

    final checklistMatch = RegExp(r'^Checklist (\d+)$').firstMatch(key);
    if (checklistMatch != null) {
      final number = checklistMatch.group(1)!;
      return language == AppLanguage.chinese
          ? '检查项 $number'
          : 'စစ်ဆေးချက် $number';
    }

    String? matchedValue(String pattern) =>
        RegExp(pattern).firstMatch(key)?.group(1);

    final averageStaff = matchedValue(r'^(.+) avg staff/day$');
    if (averageStaff != null) {
      return language == AppLanguage.chinese
          ? '$averageStaff 平均员工/天'
          : '$averageStaff ပျမ်းမျှ ဝန်ထမ်း/ရက်';
    }
    final voidExposure = matchedValue(r'^(.+)% void exposure$');
    if (voidExposure != null) {
      return language == AppLanguage.chinese
          ? '作废风险 $voidExposure%'
          : 'ပယ်ဖျက်ဘေလ် အချိုး $voidExposure%';
    }
    final outOfStock = matchedValue(r'^(\d+) out$');
    if (outOfStock != null) {
      return language == AppLanguage.chinese
          ? '$outOfStock 个缺货'
          : '$outOfStock ခု ကုန်ပြတ်';
    }
    final lowStock = matchedValue(r'^(\d+) low$');
    if (lowStock != null) {
      return language == AppLanguage.chinese
          ? '$lowStock 个低库存'
          : '$lowStock ခု လက်ကျန်နည်း';
    }
    final salesShare = matchedValue(r'^(.+)% of sales$');
    if (salesShare != null) {
      return language == AppLanguage.chinese
          ? '占销售额 $salesShare%'
          : 'ရောင်းအား၏ $salesShare%';
    }
    final completion = matchedValue(r'^(.+)% complete$');
    if (completion != null) {
      return language == AppLanguage.chinese
          ? '完成 $completion%'
          : '$completion% ပြီးစီး';
    }
    final resolved = matchedValue(r'^(.+)% resolved$');
    if (resolved != null) {
      return language == AppLanguage.chinese
          ? '已解决 $resolved%'
          : '$resolved% ဖြေရှင်းပြီး';
    }
    final compensation = matchedValue(r'^RM (.+) comp\.$');
    if (compensation != null) {
      return language == AppLanguage.chinese
          ? '赔偿 RM $compensation'
          : 'လျော်ကြေး RM $compensation';
    }
    final datedSales = matchedValue(r'^Sales · (.+)$');
    if (datedSales != null) {
      return language == AppLanguage.chinese
          ? '销售 · $datedSales'
          : 'ရောင်းအား · $datedSales';
    }
    final periodSales = matchedValue(r'^(\d+)-Day Sales$');
    if (periodSales != null) {
      return language == AppLanguage.chinese
          ? '$periodSales日销售额'
          : '$periodSales ရက် ရောင်းအား';
    }
    final periodTotalSales = matchedValue(r'^(\d+)-day total sales$');
    if (periodTotalSales != null) {
      return language == AppLanguage.chinese
          ? '$periodTotalSales天总销售额'
          : '$periodTotalSales ရက် ရောင်းအားစုစုပေါင်း';
    }
    final periodLoss = matchedValue(r'^(\d+)-day estimated loss$');
    if (periodLoss != null) {
      return language == AppLanguage.chinese
          ? '$periodLoss天预计损耗'
          : '$periodLoss ရက် ခန့်မှန်းဆုံးရှုံးမှု';
    }
    final updated = matchedValue(r'^Updated (.+)$');
    if (updated != null) {
      return language == AppLanguage.chinese
          ? '更新于 $updated'
          : 'နောက်ဆုံးပြင်ဆင်ချိန် $updated';
    }
    final openShifts = matchedValue(r'^(\d+) open shift\(s\)$');
    if (openShifts != null) {
      return language == AppLanguage.chinese
          ? '$openShifts 个未结束班次'
          : 'မပိတ်ရသေးသော အလုပ်ချိန် $openShifts ခု';
    }
    final missingCounts = matchedValue(r'^(\d+) missing SKU-day count\(s\)$');
    if (missingCounts != null) {
      return language == AppLanguage.chinese
          ? '缺少 $missingCounts 个 SKU 日盘点'
          : 'SKU-ရက် ရေတွက်မှု $missingCounts ခု လိုအပ်';
    }
    final attendanceMismatch =
        matchedValue(r'^Attendance mismatch: (\d+) day\(s\)$');
    if (attendanceMismatch != null) {
      return language == AppLanguage.chinese
          ? '考勤不匹配：$attendanceMismatch 天'
          : 'တက်ရောက်မှု မကိုက်ညီသည့်ရက် $attendanceMismatch ရက်';
    }
    final days = matchedValue(r'^(\d+) days$');
    if (days != null) {
      return language == AppLanguage.chinese ? '$days 天' : '$days ရက်';
    }
    final hours = matchedValue(r'^(.+) h$');
    if (hours != null) {
      return language == AppLanguage.chinese ? '$hours 小时' : '$hours နာရီ';
    }
    final compactDuration = RegExp(r'^(\d+)h(?: (\d+)m)?$').firstMatch(key);
    if (compactDuration != null) {
      final hourCount = compactDuration.group(1)!;
      final minuteCount = compactDuration.group(2);
      if (language == AppLanguage.chinese) {
        return minuteCount == null
            ? '$hourCount小时'
            : '$hourCount小时$minuteCount分钟';
      }
      return minuteCount == null
          ? '$hourCount နာရီ'
          : '$hourCount နာရီ $minuteCount မိနစ်';
    }
    final compactMinutes = matchedValue(r'^(\d+)m$');
    if (compactMinutes != null) {
      return language == AppLanguage.chinese
          ? '$compactMinutes分钟'
          : '$compactMinutes မိနစ်';
    }
    final longDate = RegExp(
      r'^(\d{1,2}) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d{4})$',
    ).firstMatch(key);
    if (longDate != null) {
      const monthKeys = <String>[
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      const myanmarMonths = <String>[
        'ဇန်နဝါရီ', 'ဖေဖော်ဝါရီ', 'မတ်', 'ဧပြီ', 'မေ', 'ဇွန်',
        'ဇူလိုင်', 'ဩဂုတ်', 'စက်တင်ဘာ', 'အောက်တိုဘာ', 'နိုဝင်ဘာ', 'ဒီဇင်ဘာ',
      ];
      final day = longDate.group(1)!;
      final monthIndex = monthKeys.indexOf(longDate.group(2)!);
      final year = longDate.group(3)!;
      return language == AppLanguage.chinese
          ? '$year年${monthIndex + 1}月$day日'
          : '$day ${myanmarMonths[monthIndex]} $year';
    }
    final foundCount = matchedValue(r'^(\d+) found$');
    if (foundCount != null) {
      return language == AppLanguage.chinese
          ? '找到 $foundCount 位'
          : '$foundCount ယောက် တွေ့ရှိ';
    }
    final selectedCount = matchedValue(r'^(\d+) selected$');
    if (selectedCount != null) {
      return language == AppLanguage.chinese
          ? '已选择 $selectedCount 项'
          : '$selectedCount ခု ရွေးထားသည်';
    }
    final changeCount = RegExp(r'^(\d+) changes?$').firstMatch(key)?.group(1);
    if (changeCount != null) {
      return language == AppLanguage.chinese
          ? '$changeCount 项更改'
          : 'ပြောင်းလဲမှု $changeCount ခု';
    }
    final bulkReviewAction = RegExp(
      r'^(Approve|Reject) (\d+) records\?$',
    ).firstMatch(key);
    if (bulkReviewAction != null) {
      final action = bulkReviewAction.group(1)!;
      final count = bulkReviewAction.group(2)!;
      if (language == AppLanguage.chinese) {
        return action == 'Approve' ? '批准 $count 条记录？' : '拒绝 $count 条记录？';
      }
      return action == 'Approve'
          ? 'မှတ်တမ်း $count ခုကို အတည်ပြုမည်လား။'
          : 'မှတ်တမ်း $count ခုကို ပယ်ချမည်လား။';
    }
    final assignedUsers = RegExp(
      r'^(\d+) users? assigned$',
    ).firstMatch(key)?.group(1);
    if (assignedUsers != null) {
      return language == AppLanguage.chinese
          ? '已分配 $assignedUsers 位用户'
          : 'အသုံးပြုသူ $assignedUsers ယောက် တာဝန်ပေးထားသည်';
    }
    final lastUpdated = matchedValue(r'^Last updated (.+)$');
    if (lastUpdated != null) {
      return language == AppLanguage.chinese
          ? '最后更新于 $lastUpdated'
          : 'နောက်ဆုံးပြင်ဆင်ချိန် $lastUpdated';
    }
    final createdUser = matchedValue(r'^User created · (.+)$');
    if (createdUser != null) {
      return language == AppLanguage.chinese
          ? '用户已创建 · $createdUser'
          : 'အသုံးပြုသူ ဖန်တီးပြီး · $createdUser';
    }
    final employeeBusiness = matchedValue(
      r'^This will create an employee ID only inside (.+)\.$',
    );
    if (employeeBusiness != null) {
      return language == AppLanguage.chinese
          ? '这将仅在 $employeeBusiness 内创建员工编号。'
          : '$employeeBusiness အတွင်း၌သာ ဝန်ထမ်း ID ဖန်တီးမည်။';
    }
    final rolesBusiness = matchedValue(r'^Only roles from (.+) are loaded\.$');
    if (rolesBusiness != null) {
      return language == AppLanguage.chinese
          ? '仅加载 $rolesBusiness 的角色。'
          : '$rolesBusiness မှ ရာထူးများကိုသာ ရယူထားသည်။';
    }
    final skuProgress = RegExp(
      r'^(\d+) SKU (saved|received)$',
    ).firstMatch(key);
    if (skuProgress != null) {
      final count = skuProgress.group(1)!;
      final action = skuProgress.group(2)!;
      if (language == AppLanguage.chinese) {
        return action == 'saved' ? '已保存 $count 个SKU' : '已收货 $count 个SKU';
      }
      return action == 'saved'
          ? 'SKU $count ခု သိမ်းပြီး'
          : 'SKU $count ခု လက်ခံပြီး';
    }
    final pendingCount = matchedValue(r'^(\d+) pending$');
    if (pendingCount != null) {
      return language == AppLanguage.chinese
          ? '$pendingCount 项待处理'
          : '$pendingCount ခု စောင့်ဆိုင်း';
    }
    final healthySkus = RegExp(
      r'^(\d+) of (\d+) SKUs are operating inside their configured range\.$',
    ).firstMatch(key);
    if (healthySkus != null) {
      final healthy = healthySkus.group(1)!;
      final active = healthySkus.group(2)!;
      return language == AppLanguage.chinese
          ? '$active 个SKU中有 $healthy 个处于设定范围内。'
          : 'SKU $active ခုအနက် $healthy ခုသည် သတ်မှတ်ထားသော အကွာအဝေးအတွင်း ရှိသည်။';
    }
    final genderAge = RegExp(r'^(.+) · approx\. (\d+)$').firstMatch(key);
    if (genderAge != null) {
      final genderKey = genderAge.group(1)!;
      final gender = translations[genderKey] ?? genderKey;
      final age = genderAge.group(2)!;
      return language == AppLanguage.chinese
          ? '$gender · 约 $age 岁'
          : '$gender · ခန့်မှန်းအသက် $age';
    }
    final estimatedLoss = RegExp(
      r'^(.+) (.+) · RM (.+) estimated loss$',
    ).firstMatch(key);
    if (estimatedLoss != null) {
      final quantity = estimatedLoss.group(1)!;
      final unit = estimatedLoss.group(2)!;
      final loss = estimatedLoss.group(3)!;
      return language == AppLanguage.chinese
          ? '$quantity $unit · 预计损失 RM $loss'
          : '$quantity $unit · ခန့်မှန်းဆုံးရှုံးမှု RM $loss';
    }
    final wasteConfirmation = RegExp(
      r'^(.+) · (.+) (.+) · Estimated loss RM (.+)\.$',
    ).firstMatch(key);
    if (wasteConfirmation != null) {
      final item = wasteConfirmation.group(1)!;
      final quantity = wasteConfirmation.group(2)!;
      final unit = wasteConfirmation.group(3)!;
      final loss = wasteConfirmation.group(4)!;
      return language == AppLanguage.chinese
          ? '$item · $quantity $unit · 预计损失 RM $loss。'
          : '$item · $quantity $unit · ခန့်မှန်းဆုံးရှုံးမှု RM $loss။';
    }
    final operationalPhotos = RegExp(
      r'^(\d+) operational photos submitted by (.+)\.$',
    ).firstMatch(key);
    if (operationalPhotos != null) {
      final count = operationalPhotos.group(1)!;
      final user = operationalPhotos.group(2)!;
      return language == AppLanguage.chinese
          ? '$user 已提交 $count 张运营照片。'
          : '$user က လုပ်ငန်းဓာတ်ပုံ $count ပုံ တင်ပြထားသည်။';
    }
    final lockedPhotos = matchedValue(
      r'^(\d+) photos will be locked and sent for manager approval\.$',
    );
    if (lockedPhotos != null) {
      return language == AppLanguage.chinese
          ? '$lockedPhotos 张照片将被锁定并提交经理审批。'
          : 'ဓာတ်ပုံ $lockedPhotos ပုံကို လော့ခ်ချပြီး မန်နေဂျာ အတည်ပြုရန် ပို့မည်။';
    }
    final copiedStock = RegExp(
      r'^(\d+) SKU, (\d+) tags and (\d+) suppliers copied\.$',
    ).firstMatch(key);
    if (copiedStock != null) {
      final skuCount = copiedStock.group(1)!;
      final tagCount = copiedStock.group(2)!;
      final supplierCount = copiedStock.group(3)!;
      return language == AppLanguage.chinese
          ? '已复制 $skuCount 个SKU、$tagCount 个标签和 $supplierCount 个供应商。'
          : 'SKU $skuCount ခု၊ Tag $tagCount ခုနှင့် ပေးသွင်းသူ $supplierCount ယောက် ကူးယူပြီး။';
    }
    final stockRange = RegExp(
      r'^Balance (.+) · Range (.+)–(.+)$',
    ).firstMatch(key);
    if (stockRange != null) {
      final balance = stockRange.group(1)!;
      final minimum = stockRange.group(2)!;
      final maximum = stockRange.group(3)!;
      return language == AppLanguage.chinese
          ? '库存 $balance · 范围 $minimum–$maximum'
          : 'လက်ကျန် $balance · အကွာအဝေး $minimum–$maximum';
    }
    final billConfirmation = RegExp(
      r'^Bill (.+) · RM (.+)\. (The current Sales form values will stay on this page|Photo evidence will be permanently linked)\.$',
    ).firstMatch(key);
    if (billConfirmation != null) {
      final bill = billConfirmation.group(1)!;
      final amount = billConfirmation.group(2)!;
      final detail = billConfirmation.group(3)!;
      if (language == AppLanguage.chinese) {
        return detail.startsWith('The current')
            ? '账单 $bill · RM $amount。当前销售表单的数值将保留在此页面。'
            : '账单 $bill · RM $amount。照片凭证将永久关联。';
      }
      return detail.startsWith('The current')
          ? 'ဘေလ် $bill · RM $amount။ လက်ရှိအရောင်းဖောင် တန်ဖိုးများကို ဤစာမျက်နှာတွင် ဆက်ထားမည်။'
          : 'ဘေလ် $bill · RM $amount။ ဓာတ်ပုံအထောက်အထားကို အမြဲတမ်း ချိတ်ဆက်မည်။';
    }
    final estimatedSales = matchedValue(
      r'^Estimated Total Sales RM (.+)\. Only 60% of Gross Food Delivery Sales is recognised after estimated platform commission\. Sales fields and void bills will be locked unless Head or Owner rejects the report\.$',
    );
    if (estimatedSales != null) {
      return language == AppLanguage.chinese
          ? '预计总销售额 RM $estimatedSales。扣除预估平台佣金后，仅计入外卖平台总销售额的60%。除非Head或Owner拒绝报告，否则销售字段和作废账单将被锁定。'
          : 'ခန့်မှန်းရောင်းအားစုစုပေါင်း RM $estimatedSales။ ပလက်ဖောင်းကော်မရှင် ခန့်မှန်းပြီးနောက် Food Delivery စုစုပေါင်းရောင်းအား၏ ၆၀% ကိုသာ ထည့်တွက်သည်။ Head သို့မဟုတ် Owner က အစီရင်ခံစာကို ပယ်ချမှသာ အရောင်းအကွက်များနှင့် ပယ်ဖျက်ဘေလ်များကို ပြန်ပြင်နိုင်မည်။';
    }
    final copyTarget = matchedValue(r'^Copy SKUs to (.+)\?$');
    if (copyTarget != null) {
      return language == AppLanguage.chinese
          ? '复制SKU到 $copyTarget？'
          : 'SKU များကို $copyTarget သို့ ကူးယူမည်လား။';
    }
    final copyDetails = RegExp(
      r'^The selected SKUs, tags and suppliers will be duplicated from ([\s\S]+) into ([\s\S]+)\.\n\nThis may create duplicate tags, suppliers or SKU records\. Copied records are independent and future changes will not stay synchronised\.$',
    ).firstMatch(key);
    if (copyDetails != null) {
      final source = copyDetails.group(1)!;
      final target = copyDetails.group(2)!;
      return language == AppLanguage.chinese
          ? '所选SKU、标签和供应商将从 $source 复制到 $target。\n\n这可能会创建重复的标签、供应商或SKU记录。复制的记录彼此独立，之后的更改不会保持同步。'
          : 'ရွေးထားသော SKU၊ Tag နှင့် ပေးသွင်းသူများကို $source မှ $target သို့ ကူးယူမည်။\n\nထပ်နေသော Tag၊ ပေးသွင်းသူ သို့မဟုတ် SKU မှတ်တမ်းများ ဖြစ်ပေါ်နိုင်သည်။ ကူးယူထားသော မှတ်တမ်းများသည် သီးခြားဖြစ်ပြီး နောက်ပိုင်းပြောင်းလဲမှုများ အလိုအလျောက် မကိုက်ညီပါ။';
    }
    final capturedEvidence = matchedValue(r'^(.+) Captured$');
    if (capturedEvidence != null) {
      final title = translations[capturedEvidence] ?? capturedEvidence;
      return language == AppLanguage.chinese
          ? '$title已拍摄'
          : '$title ရိုက်ယူပြီး';
    }
    final voidBillCount = RegExp(
      r'^(\d+) void bills? recorded$',
    ).firstMatch(key)?.group(1);
    if (voidBillCount != null) {
      return language == AppLanguage.chinese
          ? '已记录 $voidBillCount 张作废账单'
          : 'ပယ်ဖျက်ဘေလ် $voidBillCount ခု မှတ်တမ်းတင်ပြီး';
    }
    final moreNeeded = matchedValue(r'^(\d+) more needed$');
    if (moreNeeded != null) {
      return language == AppLanguage.chinese
          ? '还需要 $moreNeeded 张'
          : 'နောက်ထပ် $moreNeeded ပုံ လိုအပ်';
    }
    final reviewCount = matchedValue(r'^(\d+) reviews$');
    if (reviewCount != null) {
      return language == AppLanguage.chinese
          ? '$reviewCount 条评价'
          : 'သုံးသပ်ချက် $reviewCount ခု';
    }
    final sopDeleteCount = matchedValue(r'^Delete (\d+) SOPs\?$');
    if (sopDeleteCount != null) {
      return language == AppLanguage.chinese
          ? '删除 $sopDeleteCount 个SOP？'
          : 'SOP $sopDeleteCount ခုကို ဖျက်မည်လား။';
    }
    final sopDeleteDetails = RegExp(
      r'^This permanently removes (\d+) SOP (?:group|groups) and all (\d+) linked video (?:version|versions) from EastApp\. The original YouTube (?:video is|videos are) not deleted\.$',
    ).firstMatch(key);
    if (sopDeleteDetails != null) {
      final sopCount = sopDeleteDetails.group(1)!;
      final videoCount = sopDeleteDetails.group(2)!;
      return language == AppLanguage.chinese
          ? '这将从EastApp永久删除 $sopCount 个SOP组及全部 $videoCount 个关联视频版本。原始YouTube视频不会被删除。'
          : 'EastApp မှ SOP အုပ်စု $sopCount ခုနှင့် ချိတ်ဆက်ဗီဒီယိုဗားရှင်း $videoCount ခုလုံးကို အပြီးတိုင် ဖျက်မည်။ မူရင်း YouTube ဗီဒီယိုကို မဖျက်ပါ။';
    }
    final pointAdjustment = RegExp(
      r'^([+-]?\d+) points? for (.+)\.\n\nReason: ([\s\S]+)$',
    ).firstMatch(key);
    if (pointAdjustment != null) {
      final points = pointAdjustment.group(1)!;
      final user = pointAdjustment.group(2)!;
      final reason = pointAdjustment.group(3)!;
      return language == AppLanguage.chinese
          ? '为 $user 调整 $points 分。\n\n原因：$reason'
          : '$user အတွက် $points ပွိုင့် ပြင်ဆင်မည်။\n\nအကြောင်းရင်း - $reason';
    }
    final welcomeBusiness = matchedValue(r'^Welcome to (.+)$');
    if (welcomeBusiness != null) {
      return language == AppLanguage.chinese
          ? '欢迎来到 $welcomeBusiness'
          : '$welcomeBusiness မှ ကြိုဆိုပါသည်';
    }
    final switchedEmployee = matchedValue(
      r'^The application will use (.+) and only data from this business\.$',
    );
    if (switchedEmployee != null) {
      return language == AppLanguage.chinese
          ? '应用将使用员工编号 $switchedEmployee，并且只显示此业务的数据。'
          : 'အက်ပ်သည် ဝန်ထမ်း ID $switchedEmployee ကို အသုံးပြုပြီး ဤလုပ်ငန်း၏ ဒေတာကိုသာ ပြသမည်။';
    }
    final officeDistance = matchedValue(r'^(.+) km from office$');
    if (officeDistance != null) {
      return language == AppLanguage.chinese
          ? '距办公地点 $officeDistance 公里'
          : 'အလုပ်နေရာမှ $officeDistance ကီလိုမီတာ';
    }
    final officeLocation = RegExp(
      r'^Office: (.+) · GPS ±(\d+) m$',
    ).firstMatch(key);
    if (officeLocation != null) {
      final office = officeLocation.group(1)!;
      final accuracy = officeLocation.group(2)!;
      return language == AppLanguage.chinese
          ? '办公地点：$office · GPS ±$accuracy 米'
          : 'အလုပ်နေရာ - $office · GPS ±$accuracy မီတာ';
    }
    final validationMethod = matchedValue(r'^Validated by (.+) · QR \+ GPS$');
    if (validationMethod != null) {
      return language == AppLanguage.chinese
          ? '验证方式：$validationMethod · QR + GPS'
          : '$validationMethod ဖြင့် အတည်ပြုထားသည် · QR + GPS';
    }
    final leakageSummary = RegExp(
      r'^RM (.+) sales · RM (.+) void \+ waste$',
    ).firstMatch(key);
    if (leakageSummary != null) {
      final sales = leakageSummary.group(1)!;
      final leakage = leakageSummary.group(2)!;
      return language == AppLanguage.chinese
          ? '销售 RM $sales · 作废及损耗 RM $leakage'
          : 'ရောင်းအား RM $sales · ပယ်ဖျက်/စွန့်ပစ်ဆုံးရှုံးမှု RM $leakage';
    }
    final linkedVideoConfirmation = RegExp(
      r'^This will create and link the (.+) video with (.+)\. Both versions will be deleted together\.$',
    ).firstMatch(key);
    if (linkedVideoConfirmation != null) {
      final firstLanguage = translations[linkedVideoConfirmation.group(1)!] ??
          linkedVideoConfirmation.group(1)!;
      final secondLanguage = translations[linkedVideoConfirmation.group(2)!] ??
          linkedVideoConfirmation.group(2)!;
      return language == AppLanguage.chinese
          ? '这将创建并关联$firstLanguage视频与$secondLanguage视频。两个版本将一起删除。'
          : '$firstLanguage ဗီဒီယိုကို ဖန်တီးပြီး $secondLanguage ဗီဒီယိုနှင့် ချိတ်ဆက်မည်။ ဗားရှင်းနှစ်ခုလုံးကို အတူတကွ ဖျက်မည်။';
    }
    final qrScanTitle = matchedValue(r'^Scan (.+) QR$');
    if (qrScanTitle != null) {
      final action = translations[qrScanTitle] ?? qrScanTitle;
      return language == AppLanguage.chinese
          ? '扫描$action二维码'
          : '$action QR ကို စကန်ဖတ်ပါ';
    }
    final qrScanGuidance = RegExp(
      r'^Scan a valid (.+) QR code\. GPS will be captured after the QR is scanned\.$',
    ).firstMatch(key);
    if (qrScanGuidance != null) {
      final actionKey = qrScanGuidance.group(1)!;
      final action = translations[actionKey] ?? actionKey;
      return language == AppLanguage.chinese
          ? '扫描有效的$action二维码。扫描后将获取GPS位置。'
          : 'မှန်ကန်သော $action QR ကုဒ်ကို စကန်ဖတ်ပါ။ စကန်ဖတ်ပြီးနောက် GPS တည်နေရာကို ရယူမည်။';
    }
    final qrExpiry = matchedValue(r'^Valid for multiple employees until (.+)\.$');
    if (qrExpiry != null) {
      return language == AppLanguage.chinese
          ? '多名员工均可使用，有效期至 $qrExpiry。'
          : 'ဝန်ထမ်းများစွာ အသုံးပြုနိုင်ပြီး $qrExpiry အထိ သက်တမ်းရှိသည်။';
    }

    return key;
  }

  String content(String original) {
    final normalised = normaliseContentText(original);
    if (normalised.isEmpty) return original;
    return contentTranslations[normalised] ?? original;
  }
}

const Map<String, String> _myanmar = {
  '\$label required': '\$label ဖြည့်ရန်လိုအပ်သည်',
  'Access SOPs, recipes, and ingredients': 'SOP၊ ချက်နည်းနှင့် ပါဝင်ပစ္စည်းများကို ကြည့်ရှုရန်',
  'Active': 'အသုံးပြုနေသည်',
  'Advertisement': 'ကြော်ငြာ',
  'Actor': 'လုပ်ဆောင်သူ',
  'Actors': 'လုပ်ဆောင်သူများ',
  'Actual received': 'အမှန်တကယ် လက်ခံရရှိမှု',
  'Add SKU': 'SKU ထည့်ရန်',
  'Add Supplier': 'ပေးသွင်းသူ ထည့်ရန်',
  'Add Tag': 'Tag ထည့်ရန်',
  'Add any additional notes...': 'အပိုမှတ်ချက် ထည့်ပါ...',
  'Address': 'လိပ်စာ',
  'All': 'အားလုံး',
  'All Time': 'အချိန်အားလုံး',
  'All supplier messages copied': 'ပေးသွင်းသူ စာများအားလုံး ကူးယူပြီး',
  'Apply': 'အသုံးပြုရန်',
  'Approvals': 'အတည်ပြုမှုများ',
  'Approve': 'အတည်ပြုရန်',
  'Approve All': 'အားလုံး အတည်ပြုရန်',
  'Approved': 'အတည်ပြုပြီး',
  'Assign': 'တာဝန်ပေးရန်',
  'Assign SKU to user': 'SKU ကို အသုံးပြုသူထံ တာဝန်ပေးရန်',
  'Assign SKU to user.': 'SKU ကို အသုံးပြုသူထံ တာဝန်ပေးပါ။',
  'Assigned': 'တာဝန်ပေးပြီး',
  'Assigned tags cannot be deleted': 'အသုံးပြုထားသော Tag များကို ဖျက်၍မရပါ',
  'Assignee': 'တာဝန်ခံ',
  'Assignee updated': 'တာဝန်ခံ ပြင်ဆင်ပြီး',
  'Attendance': 'တက်ရောက်မှု',
  'Attendance reports': 'တက်ရောက်မှု အစီရင်ခံစာများ',
  'Audit': 'စစ်ဆေးမှတ်တမ်း',
  'Audit Inbound': 'အဝင်ပစ္စည်း စစ်ဆေးမှတ်တမ်း',
  'Audit Trail': 'ပြောင်းလဲမှု မှတ်တမ်း',
  'Average': 'ပျမ်းမျှ',
  'Back': 'နောက်သို့',
  'Backlog': 'ကျန်ရှိအလုပ်',
  'Balance': 'လက်ကျန်',
  'Balance must be Min / Max.': 'လက်ကျန်သည် အနည်းဆုံးနှင့် အများဆုံးကြား ဖြစ်ရမည်။',
  'Business': 'လုပ်ငန်း',
  'Camera only': 'ကင်မရာသာ',
  'Camera photo captured': 'ကင်မရာဓာတ်ပုံ ရိုက်ပြီး',
  'Cancel': 'ပယ်ဖျက်ရန်',
  'Capture photos, then SKU.': 'ဓာတ်ပုံရိုက်ပြီးနောက် SKU ရွေးပါ။',
  'Captured': 'ရိုက်ပြီး',
  'Career Path': 'အလုပ်အကိုင်လမ်းကြောင်း',
  'Career mentor': 'အလုပ်အကိုင် လမ်းညွှန်',
  'Climb from Staff to Head': 'ဝန်ထမ်းမှ Head အထိ တက်လှမ်းပါ',
  'Current role': 'လက်ရှိရာထူး',
  'Your climb': 'သင့်တိုးတက်မှုလမ်းကြောင်း',
  'Tap any role': 'ရာထူးတစ်ခုကို နှိပ်ပါ',
  'Staff 1': 'ဝန်ထမ်း ၁',
  'Staff 2': 'ဝန်ထမ်း ၂',
  'Supervisor': 'ကြီးကြပ်ရေးမှူး',
  'Manager': 'မန်နေဂျာ',
  'Head': 'Head',
  'Build the foundation': 'အခြေခံကို တည်ဆောက်ပါ',
  'Own the routine': 'နေ့စဉ်လုပ်ငန်းကို ကျွမ်းကျင်ပါ',
  'Guide the shift': 'အလုပ်ချိန်ကို ဦးဆောင်ပါ',
  'Lead operations': 'လုပ်ငန်းလည်ပတ်မှုကို ဦးဆောင်ပါ',
  'Reach the summit': 'ထိပ်ဆုံးသို့ ရောက်ရှိပါ',
  'Learn the essentials and build reliable daily habits.':
      'အခြေခံအလုပ်များကို လေ့လာပြီး ယုံကြည်စိတ်ချရသော နေ့စဉ်အလေ့အကျင့်များ တည်ဆောက်ပါ။',
  'Handle daily work confidently, consistently and independently.':
      'နေ့စဉ်အလုပ်များကို ယုံကြည်မှုရှိစွာ၊ တည်ငြိမ်စွာနှင့် လွတ်လပ်စွာ လုပ်ဆောင်ပါ။',
  'Support the team, spot issues early and keep the shift moving.':
      'အဖွဲ့ကို ပံ့ပိုးပါ၊ ပြဿနာများကို စောစောရှာဖွေပြီး အလုပ်ချိန်ကို ချောမွေ့စွာ လည်ပတ်စေပါ။',
  'Make decisions, develop people and own operational results.':
      'ဆုံးဖြတ်ချက်ချပါ၊ လူများကို ဖွံ့ဖြိုးစေပြီး လုပ်ငန်းရလဒ်များကို တာဝန်ယူပါ။',
  'Set direction, grow leaders and shape how the business succeeds.':
      'ဦးတည်ချက်သတ်မှတ်ပါ၊ ခေါင်းဆောင်များကို ဖွံ့ဖြိုးစေပြီး လုပ်ငန်းအောင်မြင်မှုကို ပုံဖော်ပါ။',
  'Next climb': 'နောက်တစ်ဆင့်',
  'Unlocked': 'ဖွင့်ပြီး',
  'Summit': 'ထိပ်ဆုံး',
  'Ahead': 'ရှေ့တွင်',
  'Notifications': 'အသိပေးချက်များ',
  'Business changes from other people': 'အခြားသူများ၏ လုပ်ငန်းပြောင်းလဲမှုများ',
  'No notifications yet.': 'အသိပေးချက် မရှိသေးပါ။',
  'No recent activity yet.': 'လတ်တလော လုပ်ဆောင်ချက် မရှိသေးပါ။',
  'Remove': 'ဖယ်ရှားရန်',
  'Activity Details': 'လုပ်ဆောင်ချက် အသေးစိတ်',
  'Who': 'ဘယ်သူ',
  'Area': 'ကဏ္ဍ',
  'What happened': 'ဘာဖြစ်ခဲ့သလဲ',
  'When': 'ဘယ်အချိန်',
  'Record ID': 'မှတ်တမ်း ID',
  'Change log': 'ပြောင်းလဲမှု မှတ်တမ်း',
  'Changed Value': 'ပြောင်းလဲတန်ဖိုး',
  'Checklist': 'စစ်ဆေးစာရင်း',
  'Checklist \${index + 1}': 'စစ်ဆေးချက် \${index + 1}',
  'Checklist checked': 'စစ်ဆေးစာရင်း အတည်ပြုပြီး',
  'Clear': 'ရှင်းရန်',
  'Clear All': 'အားလုံးရှင်းရန်',
  'Click to upload photo': 'ဓာတ်ပုံတင်ရန် နှိပ်ပါ',
  'Clock in/out': 'အလုပ်ဝင်/ထွက်',
  'Company ID': 'ကုမ္ပဏီ ID',
  'Complete all fields.': 'အချက်အလက်အားလုံး ဖြည့်ပါ။',
  'Complete tasks to earn points': 'ပွိုင့်ရရန် တာဝန်များပြီးစီးပါ',
  'Completed': 'ပြီးစီးပြီး',
  'Confirm': 'အတည်ပြုရန်',
  'Confirm Approve All': 'အားလုံး အတည်ပြုမည်ကို အတည်ပြုပါ',
  'Confirm Reject All': 'အားလုံး ပယ်ချမည်ကို အတည်ပြုပါ',
  'Confirm Submit All': 'အားလုံး တင်ပြမည်ကို အတည်ပြုပါ',
  'Contact': 'ဆက်သွယ်ရန်',
  'Contact Person': 'ဆက်သွယ်ရမည့်သူ',
  'Contacts': 'အဆက်အသွယ်များ',
  'Choose from contacts': 'အဆက်အသွယ်များမှ ရွေးရန်',
  'Search contacts': 'အဆက်အသွယ်များ ရှာရန်',
  'No contacts with phone numbers': 'ဖုန်းနံပါတ်ပါသော အဆက်အသွယ် မရှိပါ',
  'Full Contacts access is required. Allow it in Settings.':
      'အဆက်အသွယ်အားလုံး အသုံးပြုခွင့် လိုအပ်သည်။ Settings တွင် ခွင့်ပြုပါ။',
  "This contact's country code is not supported.":
      'ဤအဆက်အသွယ်၏ နိုင်ငံကုဒ်ကို မပံ့ပိုးပါ။',
  'Could not load contacts.': 'အဆက်အသွယ်များကို မဖွင့်နိုင်ပါ။',
  'Copy Message': 'စာကို ကူးယူရန်',
  'Count': 'ရေတွက်ရန်',
  'Count stock / receive goods / prepare restock': 'ကုန်ပစ္စည်းရေတွက်ခြင်း၊ လက်ခံခြင်းနှင့် ပြန်ဖြည့်ရန်ပြင်ဆင်ခြင်း',
  'Counted By': 'ရေတွက်သူ',
  'Create New SOP': 'SOP အသစ် ဖန်တီးရန်',
  'Create Role': 'ရာထူး ဖန်တီးရန်',
  'Create SOP': 'SOP ဖန်တီးရန်',
  'Create Supplier': 'ပေးသွင်းသူ ဖန်တီးရန်',
  'Create User': 'အသုံးပြုသူ ဖန်တီးရန်',
  'Create a Tag in Stock first.': 'Stock တွင် Tag ကို အရင်ဖန်တီးပါ။',
  'Create supplier first': 'ပေးသွင်းသူကို အရင်ဖန်တီးပါ',
  'Create suppliers': 'ပေးသွင်းသူများ ဖန်တီးရန်',
  'Create tag first': 'Tag ကို အရင်ဖန်တီးပါ',
  'Create/list SKU': 'SKU ဖန်တီး/စာရင်းကြည့်ရန်',
  'Create/list Supplier': 'ပေးသွင်းသူ ဖန်တီး/စာရင်းကြည့်ရန်',
  'Created By': 'ဖန်တီးသူ',
  'Created Date': 'ဖန်တီးသည့်ရက်',
  'Current': 'လက်ရှိ',
  'Current Balance': 'လက်ရှိလက်ကျန်',
  'Current Stock': 'လက်ရှိကုန်ပစ္စည်း',
  'Custom Category': 'စိတ်ကြိုက်အမျိုးအစား',
  'Daily Count Backlog': 'နေ့စဉ်ရေတွက်မှု ကျန်ရှိစာရင်း',
  'Daily Count Records': 'နေ့စဉ်ရေတွက်မှု မှတ်တမ်းများ',
  'Daily Count Review': 'နေ့စဉ်ရေတွက်မှု စစ်ဆေးရန်',
  'Daily count approved': 'နေ့စဉ်ရေတွက်မှု အတည်ပြုပြီး',
  'Daily count records approved': 'နေ့စဉ်ရေတွက်မှု မှတ်တမ်းများ အတည်ပြုပြီး',
  'Daily count records rejected': 'နေ့စဉ်ရေတွက်မှု မှတ်တမ်းများ ပယ်ချပြီး',
  'Daily count rejected': 'နေ့စဉ်ရေတွက်မှု ပယ်ချပြီး',
  'Daily stock count submitted': 'နေ့စဉ်ကုန်ပစ္စည်းရေတွက်မှု တင်ပြပြီး',
  'Delete': 'ဖျက်ရန်',
  'Deleted': 'ဖျက်ပြီး',
  'Description': 'ဖော်ပြချက်',
  'Description:': 'ဖော်ပြချက်:',
  'Edit': 'ပြင်ဆင်ရန်',
  'Edit SOP': 'SOP ပြင်ဆင်ရန်',
  'Employee ID': 'ဝန်ထမ်း ID',
  'Enter a valid phone number.': 'မှန်ကန်သော ဖုန်းနံပါတ် ထည့်ပါ။',
  'Enter your password': 'စကားဝှက် ထည့်ပါ',
  'Entries': 'မှတ်တမ်းအရေအတွက်',
  'Example: 0123456789': 'ဥပမာ - 0123456789',
  'Example: 1kg damaged / item missing': 'ဥပမာ - ၁ ကီလို ပျက်စီး / ပစ္စည်းပျောက်',
  'Example: Chicken': 'ဥပမာ - ကြက်သား',
  'Example: Chiller': 'ဥပမာ - အအေးခန်း',
  'Example: Fresh Farm Supplier': 'ဥပမာ - Fresh Farm ပေးသွင်းသူ',
  'Example: GTI Kampar': 'ဥပမာ - GTI Kampar',
  'Example: Mr Tan': 'ဥပမာ - ဦးတန်',
  'Expected Outcome:': 'မျှော်မှန်းရလဒ်:',
  'Filter by assignee': 'တာဝန်ခံအလိုက် စစ်ထုတ်ရန်',
  'Gallery upload disabled': 'Gallery မှ တင်ခြင်းပိတ်ထားသည်',
  'Good': 'ကောင်းမွန်',
  'Goods Received': 'ပစ္စည်းလက်ခံရရှိမှု',
  'Goods Received Photo': 'လက်ခံရရှိပစ္စည်း ဓာတ်ပုံ',
  'Home': 'အိမ်',
  'Home Dashboard': 'ပင်မစာမျက်နှာ',
  'In Use': 'အသုံးပြုနေသည်',
  'Invoice': 'ဘောင်ချာ',
  'Invoice & goods check': 'ဘောင်ချာနှင့် ပစ္စည်းစစ်ဆေးမှု',
  'Invoice Photo': 'ဘောင်ချာဓာတ်ပုံ',
  'Invoice Qty': 'ဘောင်ချာအရေအတွက်',
  'Knowledge': 'အသိပညာ',
  'Knowledge Pool': 'အသိပညာ စုစည်းရာ',
  'Language': 'ဘာသာစကား',
  'English': 'အင်္ဂလိပ်',
  'Myanmar': 'မြန်မာ',
  'Linked Video': 'ချိတ်ဆက်ထားသော ဗီဒီယို',
  'No linked video': 'ချိတ်ဆက်ဗီဒီယို မရှိ',
  'Select Language': 'ဘာသာစကား ရွေးပါ',
  'Select Video Language': 'ဗီဒီယို ဘာသာစကား ရွေးပါ',
  'Select a previously created video': 'ယခင်ဖန်တီးထားသော ဗီဒီယိုကို ရွေးပါ',
  'SOP Details': 'SOP အသေးစိတ်',
  'Video Version': 'ဗီဒီယို ဗားရှင်း',
  'Video Versions': 'ဗီဒီယို ဗားရှင်းများ',
  'Language is fixed while two video versions are linked.':
      'ဗီဒီယို ဗားရှင်းနှစ်ခု ချိတ်ဆက်ထားချိန်တွင် ဘာသာစကားကို ပြောင်း၍မရပါ။',
  'Maximum two linked videos. Linked versions are deleted together.':
      'ချိတ်ဆက်ဗီဒီယို အများဆုံး နှစ်ခုသာ။ ချိတ်ဆက်ဗားရှင်းများကို အတူဖျက်ပါမည်။',
  'Last Updated': 'နောက်ဆုံးပြင်ဆင်မှု',
  'Leaderboard': 'အဆင့်ဇယား',
  'List users': 'အသုံးပြုသူစာရင်း',
  'Load Audit': 'စစ်ဆေးမှတ်တမ်း ဖွင့်ရန်',
  'Load More': 'ပိုမိုဖော်ပြရန်',
  'Loaded': 'ဖွင့်ပြီး',
  'Loading...': 'ဖွင့်နေသည်...',
  'Low': 'နည်းနေသည်',
  'Low Stock Only': 'ကုန်နည်းသည်များသာ',
  'Manage SOP': 'SOP စီမံရန်',
  'Manage businesses': 'လုပ်ငန်းများ စီမံရန်',
  'Manage roles': 'ရာထူးများ စီမံရန်',
  'Manage roles and availability.': 'ရာထူးနှင့် အသုံးပြုနိုင်မှုကို စီမံရန်။',
  'Manage users, roles and attendance': 'အသုံးပြုသူ၊ ရာထူးနှင့် တက်ရောက်မှု စီမံရန်',
  'Manager Score': 'မန်နေဂျာအမှတ်',
  'Max': 'အများဆုံး',
  'Max Balance': 'အများဆုံးလက်ကျန်',
  'Max Price': 'အမြင့်ဆုံးဈေး',
  'Maximum': 'အများဆုံး',
  'Maximum 30 days.': 'အများဆုံး ရက် ၃၀။',
  'Media selected': 'မီဒီယာ ရွေးပြီး',
  'Message': 'စာ',
  'Message copied to clipboard': 'စာကို clipboard သို့ ကူးယူပြီး',
  'Min': 'အနည်းဆုံး',
  'Min Balance': 'အနည်းဆုံးလက်ကျန်',
  'Min Price': 'အနိမ့်ဆုံးဈေး',
  'Minimum': 'အနည်းဆုံး',
  'Module': 'ကဏ္ဍ',
  'Nic\'s Kitchen': 'Nic\'s Kitchen',
  'No SKU found': 'SKU မတွေ့ပါ',
  'No SKU found.': 'SKU မတွေ့ပါ။',
  'No SKU matches the selected filters.': 'ရွေးထားသော စစ်ထုတ်မှုနှင့် ကိုက်ညီသည့် SKU မရှိပါ။',
  'No SOP found.': 'SOP မတွေ့ပါ။',
  'No audit trail found.': 'စစ်ဆေးမှတ်တမ်း မတွေ့ပါ။',
  'No backlog records found.': 'ကျန်ရှိမှတ်တမ်း မတွေ့ပါ။',
  'No daily count found.': 'နေ့စဉ်ရေတွက်မှု မတွေ့ပါ။',
  'No low-stock SKU today.': 'ယနေ့ ကုန်နည်း SKU မရှိပါ။',
  'No receiving records found.': 'ပစ္စည်းလက်ခံမှတ်တမ်း မတွေ့ပါ။',
  'No remark provided.': 'မှတ်ချက် မရှိပါ။',
  'No supplier found': 'ပေးသွင်းသူ မတွေ့ပါ',
  'No tag found': 'Tag မတွေ့ပါ',
  'No user available.': 'အသုံးပြုသူ မရှိပါ။',
  'Non editable. Manager or Head updates inside Stock Check.': 'ပြင်၍မရပါ။ Manager သို့မဟုတ် Head က Stock Check ထဲတွင် ပြင်ဆင်ရမည်။',
  'None': 'မရှိ',
  'Notes': 'မှတ်စုများ',
  'Open Camera': 'ကင်မရာဖွင့်ရန်',
  'Operation': 'လုပ်ငန်းစဉ်',
  'Optional camera proof': 'မလိုအပ်လျှင် ချန်ထားနိုင်သော ကင်မရာအထောက်အထား',
  'Overdue, rejected and approved records.': 'နောက်ကျ၊ ပယ်ချနှင့် အတည်ပြုမှတ်တမ်းများ။',
  'Password': 'စကားဝှက်',
  'Pending': 'စောင့်ဆိုင်း',
  'Pending Review': 'စစ်ဆေးရန် စောင့်ဆိုင်း',
  'Pending Reviews': 'စစ်ဆေးရန် စောင့်ဆိုင်း',
  'People': 'ဝန်ထမ်းများ',
  'People Dashboard': 'ဝန်ထမ်း စီမံခန့်ခွဲမှု',
  'Phone': 'ဖုန်း',
  'Phone Number': 'ဖုန်းနံပါတ်',
  'Photo Evidence': 'ဓာတ်ပုံအထောက်အထား',
  'Photo required': 'ဓာတ်ပုံ လိုအပ်သည်',
  'Photo selected': 'ဓာတ်ပုံ ရွေးပြီး',
  'Picture': 'ပုံ',
  'Please confirm these daily count records before applying bulk action.': 'အစုလိုက်လုပ်ဆောင်မှုမပြုမီ နေ့စဉ်ရေတွက်မှတ်တမ်းများကို အတည်ပြုပါ။',
  'Please confirm these receiving records before applying bulk action.': 'အစုလိုက်လုပ်ဆောင်မှုမပြုမီ လက်ခံမှတ်တမ်းများကို အတည်ပြုပါ။',
  'Please confirm these receiving records before submitting.': 'မတင်ပြမီ လက်ခံမှတ်တမ်းများကို အတည်ပြုပါ။',
  'Please enter valid numbers.': 'မှန်ကန်သော ကိန်းဂဏန်းများ ထည့်ပါ။',
  'Points Earned': 'ရရှိသော ပွိုင့်',
  'Previous Value': 'ယခင်တန်ဖိုး',
  'Price': 'ဈေးနှုန်း',
  'Price must be Min / Max.': 'ဈေးနှုန်းသည် အနိမ့်ဆုံးနှင့် အမြင့်ဆုံးကြား ဖြစ်ရမည်။',
  'Purchase': 'ဝယ်ယူမှု',
  'Qty on invoice': 'ဘောင်ချာပါ အရေအတွက်',
  'Ready': 'အဆင်သင့်',
  'Received At': 'လက်ခံသည့်အချိန်',
  'Received By': 'လက်ခံသူ',
  'Received Qty': 'လက်ခံရရှိအရေအတွက်',
  'Receiving': 'ပစ္စည်းလက်ခံခြင်း',
  'Receiving Backlog': 'ပစ္စည်းလက်ခံမှု ကျန်ရှိစာရင်း',
  'Receiving Checklist': 'ပစ္စည်းလက်ခံ စစ်ဆေးစာရင်း',
  'Receiving Records': 'ပစ္စည်းလက်ခံမှတ်တမ်းများ',
  'Receiving Review': 'ပစ္စည်းလက်ခံမှု စစ်ဆေးရန်',
  'Receiving record approved': 'ပစ္စည်းလက်ခံမှတ်တမ်း အတည်ပြုပြီး',
  'Receiving record rejected': 'ပစ္စည်းလက်ခံမှတ်တမ်း ပယ်ချပြီး',
  'Receiving records approved': 'ပစ္စည်းလက်ခံမှတ်တမ်းများ အတည်ပြုပြီး',
  'Receiving records rejected': 'ပစ္စည်းလက်ခံမှတ်တမ်းများ ပယ်ချပြီး',
  'Report': 'အစီရင်ခံစာ',
  'Daily Photos': 'နေ့စဉ်ဓာတ်ပုံများ',
  'Photos Taken': 'ရိုက်ထားသောဓာတ်ပုံများ',
  'Receiving submitted': 'ပစ္စည်းလက်ခံမှု တင်ပြပြီး',
  'Recent Activity': 'လတ်တလော လှုပ်ရှားမှု',
  'Recovery': 'ပြန်လည်ရယူမှု',
  'Reject': 'ပယ်ချရန်',
  'Reject All': 'အားလုံး ပယ်ချရန်',
  'Reject reason, optional': 'ပယ်ချရသည့်အကြောင်းရင်း (မထည့်လည်းရ)',
  'Rejected': 'ပယ်ချပြီး',
  'Reload Audit': 'စစ်ဆေးမှတ်တမ်း ပြန်ဖွင့်ရန်',
  'Remark': 'မှတ်ချက်',
  'Remarks (Optional)': 'မှတ်ချက် (မထည့်လည်းရ)',
  'Required': 'လိုအပ်သည်',
  'Reset': 'ပြန်သတ်မှတ်ရန်',
  'Reset Time': 'ပြန်သတ်မှတ်ချိန်',
  'Reset Time required': 'ပြန်သတ်မှတ်ချိန် လိုအပ်သည်',
  'Restock': 'ကုန်ပြန်ဖြည့်ရန်',
  'Retake Photo': 'ဓာတ်ပုံ ပြန်ရိုက်ရန်',
  'Review': 'စစ်ဆေးရန်',
  'Review Note': 'စစ်ဆေးမှတ်ချက်',
  'Review Status': 'စစ်ဆေးအခြေအနေ',
  'Review Submission': 'တင်ပြမှု စစ်ဆေးရန်',
  'Review daily counts and receiving records.': 'နေ့စဉ်ရေတွက်မှုနှင့် ပစ္စည်းလက်ခံမှတ်တမ်းများကို စစ်ဆေးပါ။',
  'Review staff submissions and rate out of 10': 'ဝန်ထမ်းတင်ပြမှုများကို စစ်ဆေးပြီး ၁၀ မှတ်အတွင်း အမှတ်ပေးပါ',
  'Review the message, then copy and paste it to supplier chat.': 'စာကို စစ်ဆေးပြီး ပေးသွင်းသူ chat ထဲသို့ ကူးထည့်ပါ။',
  'Reviewed At': 'စစ်ဆေးသည့်အချိန်',
  'Reviewed By': 'စစ်ဆေးသူ',
  'Role': 'ရာထူး',
  'SKU': 'SKU',
  'SKU Name': 'SKU အမည်',
  'SKU Photo': 'SKU ဓာတ်ပုံ',
  'SKU created': 'SKU ဖန်တီးပြီး',
  'SOP created. Staff can view it now.': 'SOP ဖန်တီးပြီး။ ဝန်ထမ်းများ ကြည့်နိုင်ပါပြီ။',
  'SOP deleted.': 'SOP ဖျက်ပြီးပါပြီ။',
  'SOPs deleted.': 'SOP များ ဖျက်ပြီးပါပြီ။',
  'SOP updated.': 'SOP ပြင်ဆင်ပြီးပါပြီ။',
  'Save': 'သိမ်းရန်',
  'Save SKU': 'SKU သိမ်းရန်',
  'Save Supplier': 'ပေးသွင်းသူ သိမ်းရန်',
  'Saved': 'သိမ်းပြီး',
  'Saving...': 'သိမ်းနေသည်...',
  'Schedule': 'အလုပ်ချိန်ဇယား',
  'Search': 'ရှာရန်',
  'Search SKU or user': 'SKU သို့မဟုတ် အသုံးပြုသူ ရှာရန်',
  'Search SOP...': 'SOP ရှာရန်...',
  'Search and edit users.': 'အသုံးပြုသူများကို ရှာပြီး ပြင်ဆင်ရန်။',
  'Search audit trail': 'စစ်ဆေးမှတ်တမ်း ရှာရန်',
  'Search backlog': 'ကျန်ရှိစာရင်း ရှာရန်',
  'Search daily count': 'နေ့စဉ်ရေတွက်မှု ရှာရန်',
  'Search receiving': 'ပစ္စည်းလက်ခံမှု ရှာရန်',
  'Search roles': 'ရာထူးများ ရှာရန်',
  'Search supplier': 'ပေးသွင်းသူ ရှာရန်',
  'Search tag': 'Tag ရှာရန်',
  'Search users': 'အသုံးပြုသူများ ရှာရန်',
  'Search, filter and edit SKU.': 'SKU ကို ရှာ၊ စစ်ထုတ်ပြီး ပြင်ဆင်ရန်။',
  'Select': 'ရွေးရန်',
  'Select Date Range': 'ရက်အပိုင်းအခြား ရွေးရန်',
  'Select SKU': 'SKU ရွေးရန်',
  'Select SKU first.': 'SKU ကို အရင်ရွေးပါ။',
  'Select SOP': 'SOP ရွေးရန်',
  'Select All': 'အားလုံးရွေးရန်',
  'selected': 'ခု ရွေးထားသည်',
  'Select Tag': 'Tag ရွေးရန်',
  'Select Video / Picture': 'ဗီဒီယို / ပုံ ရွေးရန်',
  'Select a date range, then load the audit trail.': 'ရက်အပိုင်းအခြားရွေးပြီး စစ်ဆေးမှတ်တမ်း ဖွင့်ပါ။',
  'Select at least one record': 'အနည်းဆုံး မှတ်တမ်းတစ်ခု ရွေးပါ',
  'Setup - Owner & Head': 'စနစ်ပြင်ဆင်မှု - Owner နှင့် Head',
  'Shift planning': 'အလုပ်ချိန် စီစဉ်မှု',
  'Showing': 'ပြသနေသည်',
  'Sign In': 'ဝင်ရောက်ရန်',
  'Staff Remark': 'ဝန်ထမ်းမှတ်ချက်',
  'Standard Operating Procedure': 'စံလုပ်ငန်းစဉ်',
  'State changes only. Select up to 30 days.': 'အခြေအနေပြောင်းလဲမှုများသာ။ ရက် ၃၀ အထိ ရွေးနိုင်သည်။',
  'Status': 'အခြေအနေ',
  'Stock': 'ကုန်ပစ္စည်း',
  'Stock Balance': 'ကုန်လက်ကျန်',
  'Stock Dashboard': 'ကုန်ပစ္စည်း စီမံခန့်ခွဲမှု',
  'Stock Level': 'ကုန်လက်ကျန်အဆင့်',
  'Stock Thumbnail': 'ကုန်ပစ္စည်းပုံငယ်',
  'Stock Thumbnail required': 'ကုန်ပစ္စည်းပုံငယ် လိုအပ်သည်',
  'Submissions Reviewed': 'စစ်ဆေးပြီးသော တင်ပြမှုများ',
  'Submit All': 'အားလုံး တင်ပြရန်',
  'Submit Daily Count': 'နေ့စဉ်ရေတွက်မှု တင်ပြရန်',
  'Submit Task': 'တာဝန်တင်ပြရန်',
  'Submit for Approval': 'အတည်ပြုရန် တင်ပြပါ',
  'Submitted': 'တင်ပြပြီး',
  'Submitted just now': 'ယခုတင်ပြပြီး',
  'Submitted recently': 'မကြာသေးမီက တင်ပြပြီး',
  'Supplier': 'ပေးသွင်းသူ',
  'Supplier Name': 'ပေးသွင်းသူအမည်',
  'Supplier Purchase Setup': 'ပေးသွင်းသူ ဝယ်ယူမှုစနစ်',
  'Supplier created': 'ပေးသွင်းသူ ဖန်တီးပြီး',
  'Supplier purchase setup is managed by Head': 'ပေးသွင်းသူဝယ်ယူမှုစနစ်ကို Head က စီမံသည်',
  'Supplier required': 'ပေးသွင်းသူ လိုအပ်သည်',
  'Supplier restock message copied': 'ပေးသွင်းသူထံ ကုန်ပြန်ဖြည့်စာ ကူးယူပြီး',
  'Suppliers': 'ပေးသွင်းသူများ',
  'Suppliers link inside SKU Setup.': 'ပေးသွင်းသူချိတ်ဆက်မှုကို SKU Setup ထဲတွင် စီမံသည်။',
  'Tag': 'Tag',
  'Tag 1': 'Tag 1',
  'Tag 1 required': 'Tag 1 လိုအပ်သည်',
  'Tag 2': 'Tag 2',
  'Tag 2 required': 'Tag 2 လိုအပ်သည်',
  'Tag already exists': 'Tag ရှိပြီးသားဖြစ်သည်',
  'Tag is required': 'Tag လိုအပ်သည်',
  'Take Photo': 'ဓာတ်ပုံရိုက်ရန်',
  'Take a fresh photo of the supplier invoice.': 'ပေးသွင်းသူဘောင်ချာကို အသစ်ပြန်ရိုက်ပါ။',
  'Take one photo showing the goods received for this supplier.': 'ဤပေးသွင်းသူထံမှ လက်ခံရရှိသောပစ္စည်းများကို ဓာတ်ပုံတစ်ပုံရိုက်ပါ။',
  'Tap photo to view. Tap balance to update.': 'ကြည့်ရန် ဓာတ်ပုံကို နှိပ်ပါ။ ပြင်ရန် လက်ကျန်ကို နှိပ်ပါ။',
  'Tap supplier to preview message.': 'စာကြိုကြည့်ရန် ပေးသွင်းသူကို နှိပ်ပါ။',
  'Task Approvals': 'တာဝန် အတည်ပြုမှုများ',
  'Task approved': 'တာဝန် အတည်ပြုပြီး',
  'Task rejected': 'တာဝန် ပယ်ချပြီး',
  'Task submitted for manager approval': 'မန်နေဂျာ အတည်ပြုရန် တာဝန်တင်ပြပြီး',
  'Task': 'တာဝန်',
  'Tasks': 'တာဝန်များ',
  'Tasks Completed': 'ပြီးစီးသော တာဝန်များ',
  'Tasks done': 'ပြီးစီးသော တာဝန်များ',
  'This Month': 'ဒီလ',
  'This Week': 'ဒီအပတ်',
  'Timer': 'အချိန်တွက်စက်',
  'Title': 'ခေါင်းစဉ်',
  'Today': 'ယနေ့',
  'Today\'s Progress': 'ယနေ့ တိုးတက်မှု',
  'Today\'s Reviews': 'ယနေ့ စစ်ဆေးမှု',
  'Total': 'စုစုပေါင်း',
  'Total Points': 'စုစုပေါင်း ပွိုင့်',
  'Total SKU': 'SKU စုစုပေါင်း',
  'Transparent point ranking': 'ပွိုင့်အဆင့်ဇယား',
  'Unassigned': 'တာဝန်မပေးရသေး',
  'Unassigned Supplier': 'ပေးသွင်းသူ မသတ်မှတ်ရသေး',
  'Unit': 'ယူနစ်',
  'Up 3 ranks': 'အဆင့် ၃ ဆင့် တက်',
  'Update daily physical stock balance': 'နေ့စဉ် အမှန်တကယ်ကုန်လက်ကျန် ပြင်ဆင်ရန်',
  'Upload Photo Evidence *': 'ဓာတ်ပုံအထောက်အထား တင်ရန် *',
  'Upload Video / Picture': 'ဗီဒီယို / ပုံ တင်ရန်',
  'User': 'အသုံးပြုသူ',
  'Valid number required': 'မှန်ကန်သော ကိန်းဂဏန်း လိုအပ်သည်',
  'Video': 'ဗီဒီယို',
  'Video tutorial available': 'ဗီဒီယိုလမ်းညွှန် ရှိသည်',
  'View SOP': 'SOP ကြည့်ရန်',
  'View Tasks': 'တာဝန်များကြည့်ရန်',
  'View attendance': 'တက်ရောက်မှု ကြည့်ရန်',
  'View roles': 'ရာထူးများ ကြည့်ရန်',
  'View roles.': 'ရာထူးများ ကြည့်ရန်။',
  'View users.': 'အသုံးပြုသူများ ကြည့်ရန်။',
  'Watch Video': 'ဗီဒီယိုကြည့်ရန်',
  'Your Current Rank': 'လက်ရှိအဆင့်',
  'Settings': 'ဆက်တင်များ',
  'Localisation': 'အက်ပ် ဘာသာစကား',
  'Translate': 'ဘာသာပြန်ရန်',
  'Chinese': 'တရုတ်',
  'Close': 'ပိတ်ရန်',
  'Original content (off)': 'မူရင်းအကြောင်းအရာ (ပိတ်)',
  'Choose the language for fixed app labels.':
      'အက်ပ်၏ သတ်မှတ်စာသားများအတွက် ဘာသာစကားကို ရွေးပါ။',
  'Translate user-entered content. The original and both translations are stored for reuse.':
      'အသုံးပြုသူထည့်သွင်းထားသော အကြောင်းအရာကို ဘာသာပြန်ပါ။ မူရင်းနှင့် ဘာသာပြန်နှစ်မျိုးလုံးကို ပြန်လည်အသုံးပြုရန် သိမ်းဆည်းထားသည်။',
  'Save settings': 'ဆက်တင်များကို သိမ်းရန်',
  'Saving settings...': 'ဆက်တင်များကို သိမ်းနေသည်...',
  'Checking the translation cache...': 'ဘာသာပြန် cache ကို စစ်ဆေးနေသည်...',
  'Applying translation...': 'ဘာသာပြန်ခြင်းကို အသုံးပြုနေသည်...',
  'Translation cost confirmation': 'ဘာသာပြန် ကုန်ကျစရိတ် အတည်ပြုခြင်း',
  'The cache check is complete. Cloudflare has not been called.':
      'Cache စစ်ဆေးမှု ပြီးပါပြီ။ Cloudflare ကို မခေါ်ရသေးပါ။',
  'Content found this session': 'ဤ session တွင် တွေ့ရှိသော အကြောင်းအရာ',
  'Stored translations': 'သိမ်းထားသော ဘာသာပြန်များ',
  'Selected-language cache misses': 'ရွေးထားသော ဘာသာစကား cache မရှိမှု',
  'Companion-language cache misses': 'တွဲဖက် ဘာသာစကား cache မရှိမှု',
  'New Cloudflare requests': 'Cloudflare တောင်းဆိုမှု အသစ်',
  'Cloudflare is unavailable. Missing selected-language translations cannot be completed.':
      'Cloudflare မရနိုင်ပါ။ ရွေးထားသော ဘာသာစကား၏ မရှိသေးသော ဘာသာပြန်များကို မပြီးစီးနိုင်ပါ။',
  'Cloudflare is unavailable, but the selected language is fully cached and can be used without a provider call.':
      'Cloudflare မရနိုင်သော်လည်း ရွေးထားသော ဘာသာစကားကို cache အပြည့်ရှိသောကြောင့် provider မခေါ်ဘဲ အသုံးပြုနိုင်ပါသည်။',
  'Cloudflare Workers AI may create billable usage for these new requests. Use carefully.':
      'ဤတောင်းဆိုမှုအသစ်များသည် Cloudflare Workers AI တွင် အခကြေးငွေကျနိုင်ပါသည်။ သတိထားအသုံးပြုပါ။',
  'Everything required is cached. Confirming will not call Cloudflare.':
      'လိုအပ်သမျှ cache ထဲတွင် ရှိပါသည်။ အတည်ပြုလျှင် Cloudflare ကို မခေါ်ပါ။',
  'Exact behaviour': 'လုပ်ဆောင်ပုံ အတိအကျ',
  'Changing a dropdown does nothing until Save.':
      'Dropdown ကို ပြောင်းရုံဖြင့် မလုပ်ဆောင်ပါ။ Save နှိပ်မှသာ စတင်ပါသည်။',
  'Back or forward navigation never calls Cloudflare.':
      'စာမျက်နှာ နောက်သို့ သို့မဟုတ် ရှေ့သို့ သွားခြင်းသည် Cloudflare ကို မခေါ်ပါ။',
  'Save checks PostgreSQL first; cache hits do not call Cloudflare.':
      'Save သည် PostgreSQL ကို ဦးစွာ စစ်ဆေးပြီး cache ရှိလျှင် Cloudflare ကို မခေါ်ပါ။',
  'Only missing translations call Cloudflare after confirmation.':
      'အတည်ပြုပြီးနောက် မရှိသေးသော ဘာသာပြန်များအတွက်သာ Cloudflare ကို ခေါ်ပါသည်။',
  'One uncached source can create up to two Cloudflare requests because both other languages are stored.':
      'အခြားဘာသာစကားနှစ်မျိုးလုံးကို သိမ်းသောကြောင့် cache မရှိသော မူရင်းစာတစ်ခုသည် Cloudflare တောင်းဆိုမှု နှစ်ခုအထိ ဖြစ်စေနိုင်ပါသည်။',
  'Save includes matching content discovered on visited pages in the current sign-in session, not only the visible page.':
      'Save သည် လက်ရှိမြင်နေရသောစာမျက်နှာသာမက ဤ sign-in session အတွင်း ဝင်ကြည့်ခဲ့သော စာမျက်နှာများမှ ကိုက်ညီသည့်အကြောင်းအရာများကိုပါ ထည့်တွက်ပါသည်။',
  'Newly loaded content stays original until the next Save.':
      'အသစ်ဖွင့်ထားသော အကြောင်းအရာသည် နောက်တစ်ကြိမ် Save မနှိပ်မချင်း မူရင်းအတိုင်း ရှိနေပါမည်။',
  'Double-clicking Save or Confirm does not send another request.':
      'Save သို့မဟုတ် Confirm ကို နှစ်ချက်နှိပ်လျှင် နောက်ထပ်တောင်းဆိုမှု မပို့ပါ။',
  'Localisation changes fixed labels only and never calls Cloudflare.':
      'Localisation သည် အက်ပ်၏ သတ်မှတ်စာသားများကိုသာ ပြောင်းပြီး Cloudflare ကို မခေါ်ပါ။',
  'Saving Original content (off) never calls Cloudflare.':
      'Original content (off) ကို သိမ်းခြင်းသည် Cloudflare ကို မခေါ်ပါ။',
  'Cloudflare may record billable usage even if a submitted provider request later fails.':
      'ပို့ပြီးသော provider တောင်းဆိုမှု နောက်ပိုင်း မအောင်မြင်သော်လည်း Cloudflare တွင် အခကြေးငွေကျနိုင်သော အသုံးပြုမှုအဖြစ် မှတ်တမ်းတင်နိုင်ပါသည်။',
  'This estimate uses the current database cache. Another completed translation can only reduce the actual request count.':
      'ဤခန့်မှန်းချက်သည် လက်ရှိ database cache ကို အသုံးပြုထားသည်။ အခြားဘာသာပြန်မှု ပြီးသွားလျှင် အမှန်တကယ်တောင်းဆိုမှု အရေအတွက် လျော့နိုင်သည်။',
  'Confirm & translate': 'အတည်ပြုပြီး ဘာသာပြန်ရန်',
  'Use cache & save': 'Cache ကို အသုံးပြုပြီး သိမ်းရန်',
  'Action': 'လုပ်ဆောင်ချက်',
  'Add or deduct points': 'ပွိုင့် ထည့်ရန် သို့မဟုတ် နုတ်ရန်',
  'Assign or deduct accumulated points':
      'စုဆောင်းပွိုင့် သတ်မှတ်ရန် သို့မဟုတ် နုတ်ရန်',
  'Assignment status': 'တာဝန်ပေးမှု အခြေအနေ',
  'Current business · All time': 'လက်ရှိလုပ်ငန်း · အချိန်အားလုံး',
  'Done': 'ပြီးပါပြီ',
  'Goods received photo captured': 'ကုန်လက်ခံဓာတ်ပုံ ရိုက်ယူပြီး',
  'Invoice photo captured': 'ငွေတောင်းခံလွှာဓာတ်ပုံ ရိုက်ယူပြီး',
  'Load': 'ဒေတာရယူရန်',
  'Load Assigned or Unassigned SKU only when needed.':
      'လိုအပ်သည့်အခါ တာဝန်ပေးပြီး သို့မဟုတ် မပေးရသေးသော SKU များကိုသာ ရယူပါ။',
  'Load more': 'နောက်ထပ် ရယူရန်',
  'Load more users': 'နောက်ထပ် အသုံးပြုသူများ ရယူရန်',
  'No SKU matches the selected criteria.':
      'ရွေးထားသော စံနှုန်းများနှင့် ကိုက်ညီသော SKU မရှိပါ။',
  'Nothing is loaded by default. Select Assigned or Unassigned, then press Load.':
      'ပုံမှန်အားဖြင့် ဒေတာမရယူထားပါ။ Assigned သို့မဟုတ် Unassigned ကို ရွေးပြီး Load နှိပ်ပါ။',
  'Points': 'ပွိုင့်',
  'Processing... Please Wait!': 'လုပ်ဆောင်နေသည်... ကျေးဇူးပြု၍ စောင့်ပါ!',
  'Results': 'ရလဒ်များ',
  'Retry': 'ပြန်ကြိုးစားရန်',
  'Review submitted daily stock counts':
      'တင်ပြထားသော နေ့စဉ်ကုန်လက်ကျန်စာရင်းများကို စစ်ဆေးရန်',
  'Review submitted receiving records':
      'တင်ပြထားသော ကုန်လက်ခံမှတ်တမ်းများကို စစ်ဆေးရန်',
  'Search SKU (optional)': 'SKU ရှာရန် (ရွေးချယ်နိုင်)',
  'Select Status AND Date, then press Search.':
      'အခြေအနေနှင့် ရက်စွဲကို ရွေးပြီး Search နှိပ်ပါ။',
  'Submitted counts cannot be edited.':
      'တင်ပြပြီးသော စာရင်းများကို ပြင်၍မရပါ။',
  'Take a clear photo of this SKU.': 'ဤ SKU ကို ကြည်လင်စွာ ဓာတ်ပုံရိုက်ပါ။',
  'View role hierarchy': 'ရာထူးအဆင့်ဆင့်ကို ကြည့်ရန်',
  'Cash Total': 'ငွေသားစုစုပေါင်း',
  'eWallet Total': 'eWallet စုစုပေါင်း',
  'Gross Delivery': 'ပို့ဆောင်ရောင်းချမှု စုစုပေါင်း',
  'Net Delivery (60%)': 'အသားတင် ပို့ဆောင်ရောင်းချမှု (60%)',
  'Platform Commission': 'ပလက်ဖောင်း ကော်မရှင်',
  'Total Sales': 'ရောင်းအားစုစုပေါင်း',
  'Staff on Duty': 'တာဝန်ကျ ဝန်ထမ်း',
  'Sales / Staff-Day': 'ဝန်ထမ်း-ရက်အလိုက် ရောင်းအား',
  'Void Total': 'ပယ်ဖျက်ဘေလ် စုစုပေါင်း',
  'Void Exposure': 'ပယ်ဖျက်ဘေလ် အချိုး',
  'Net Delivery': 'အသားတင် ပို့ဆောင်ရောင်းချမှု',
  'Stock Value': 'ကုန်ပစ္စည်းတန်ဖိုး',
  'Reorder Need': 'ပြန်လည်မှာယူရန် လိုအပ်မှု',
  'Overstock Capital': 'ပိုလျှံကုန်ပစ္စည်း ရင်းနှီးငွေ',
  'Out / Low': 'ကုန်ပြတ် / လက်ကျန်နည်း',
  'Copied SKU from another business': 'အခြားလုပ်ငန်းမှ SKU ကူးယူခဲ့သည်',
  'Created tag': 'Tag ဖန်တီးခဲ့သည်',
  'Renamed tag': 'Tag အမည်ပြောင်းခဲ့သည်',
  'Deleted tag': 'Tag ဖျက်ခဲ့သည်',
  'Created supplier': 'ပေးသွင်းသူ ဖန်တီးခဲ့သည်',
  'Edited supplier': 'ပေးသွင်းသူ ပြင်ဆင်ခဲ့သည်',
  'Deleted supplier': 'ပေးသွင်းသူ ဖျက်ခဲ့သည်',
  'Supplier Balance': 'ပေးသွင်းသူ လက်ကျန်',
  'Updated supplier balance': 'ပေးသွင်းသူ လက်ကျန် ပြင်ဆင်ခဲ့သည်',
  'Created SKU': 'SKU ဖန်တီးခဲ့သည်',
  'Edited SKU': 'SKU ပြင်ဆင်ခဲ့သည်',
  'SKU Balance': 'SKU လက်ကျန်',
  'Updated balance': 'လက်ကျန် ပြင်ဆင်ခဲ့သည်',
  'Stock Count': 'ကုန်ပစ္စည်း ရေတွက်မှု',
  'Submitted daily count': 'နေ့စဉ် ရေတွက်မှု တင်ပြခဲ့သည်',
  'Reviewed daily count': 'နေ့စဉ် ရေတွက်မှု စစ်ဆေးခဲ့သည်',
  'Bulk reviewed daily count': 'နေ့စဉ် ရေတွက်မှုများကို အစုလိုက် စစ်ဆေးခဲ့သည်',
  'Submitted receiving': 'ကုန်လက်ခံမှု တင်ပြခဲ့သည်',
  'Reviewed receiving': 'ကုန်လက်ခံမှု စစ်ဆေးခဲ့သည်',
  'Source Business': 'မူရင်းလုပ်ငန်း',
  'Supplier Item': 'ပေးသွင်းသည့် ပစ္စည်း',
  'Name': 'အမည်',
  'Photo': 'ဓာတ်ပုံ',
  'Items': 'ပစ္စည်းများ',
  'Sales Reports': 'အရောင်းအစီရင်ခံစာများ',
  'Sales Report': 'အရောင်းအစီရင်ခံစာ',
  'Void Bill Evidence': 'ပယ်ဖျက်ဘေလ် အထောက်အထား',
  'Inventory Intelligence': 'ကုန်ပစ္စည်း အသိဉာဏ်ခွဲခြမ်းစိတ်ဖြာမှု',
  'Waste Intelligence': 'စွန့်ပစ်မှု အသိဉာဏ်ခွဲခြမ်းစိတ်ဖြာမှု',
  'Complaints': 'တိုင်ကြားချက်များ',
  'Report Approvals': 'အစီရင်ခံစာ အတည်ပြုမှုများ',
  'Review & Decide': 'စစ်ဆေးပြီး ဆုံးဖြတ်ရန်',
  'Report Intelligence': 'အစီရင်ခံစာ အသိဉာဏ်ခွဲခြမ်းစိတ်ဖြာမှု',
  'Operational evidence transformed into business decisions':
      'လုပ်ငန်းအထောက်အထားများကို စီးပွားရေးဆုံးဖြတ်ချက်များအဖြစ် ပြောင်းလဲပေးသည်',
  'Refresh report data': 'အစီရင်ခံစာဒေတာ ပြန်လည်ရယူရန်',
  'Avg Sales / Reporting Day': 'အစီရင်ခံရက်အလိုက် ပျမ်းမျှရောင်းအား',
  'Count Coverage': 'ရေတွက်မှု လွှမ်းခြုံနှုန်း',
  'Total Labour Hours': 'အလုပ်ချိန်စုစုပေါင်း',
  'Sales / Labour Hour': 'အလုပ်ချိန်တစ်နာရီအလိုက် ရောင်းအား',
  'Avg Staff / Day': 'တစ်ရက်ပျမ်းမျှ ဝန်ထမ်း',
  'Complete': 'ပြီးစီး',
  'Not loaded': 'မရယူရသေး',
  'Sales': 'ရောင်းအား',
  'Waste': 'စွန့်ပစ်မှု',
  'Evidence': 'အထောက်အထား',
  'Restricted': 'ကန့်သတ်ထားသည်',
  'Submit': 'တင်ပြရန်',
  'Daily revenue, productivity and void-control intelligence':
      'နေ့စဉ်ဝင်ငွေ၊ လုပ်ဆောင်ရည်နှင့် ပယ်ဖျက်ဘေလ်ထိန်းချုပ်မှု ခွဲခြမ်းစိတ်ဖြာချက်',
  'Record every void bill with compulsory photo evidence':
      'ပယ်ဖျက်ဘေလ်တိုင်းကို မဖြစ်မနေ ဓာတ်ပုံအထောက်အထားဖြင့် မှတ်တမ်းတင်ပါ',
  'Void-control reporting': 'ပယ်ဖျက်ဘေလ် ထိန်းချုပ်မှု အစီရင်ခံခြင်း',
  'Create today’s Sales Report': 'ယနေ့ အရောင်းအစီရင်ခံစာ ဖန်တီးရန်',
  'Calculated stock health, capital exposure and reorder priorities':
      'တွက်ချက်ထားသော ကုန်လက်ကျန်အခြေအနေ၊ ရင်းနှီးငွေအန္တရာယ်နှင့် ပြန်မှာရန် ဦးစားပေးချက်များ',
  'Management-only calculated business intelligence':
      'စီမံခန့်ခွဲသူများအတွက်သာ စီးပွားရေးခွဲခြမ်းစိတ်ဖြာမှု',
  'Inventory health score': 'ကုန်လက်ကျန် အခြေအနေအမှတ်',
  'Management view': 'စီမံခန့်ခွဲမှု မြင်ကွင်း',
  'Capture evidence and calculate the real cost of wastage':
      'အထောက်အထားယူပြီး စွန့်ပစ်မှု၏ အမှန်တကယ်ကုန်ကျစရိတ်ကို တွက်ချက်ပါ',
  'Waste evidence': 'စွန့်ပစ်မှု အထောက်အထား',
  'Every staff submits at least 5 photos; manager approves the batch':
      'ဝန်ထမ်းတိုင်း အနည်းဆုံး ဓာတ်ပုံ ၅ ပုံတင်ပြီး မန်နေဂျာက အစုလိုက်အတည်ပြုသည်',
  'Staff completed today': 'ယနေ့ ပြီးစီးသော ဝန်ထမ်း',
  'Your photos today': 'ယနေ့ သင့်ဓာတ်ပုံများ',
  'Track customer profile, action, compensation and resolution':
      'ဖောက်သည်အချက်အလက်၊ လုပ်ဆောင်မှု၊ လျော်ကြေးနှင့် ဖြေရှင်းမှုကို ခြေရာခံပါ',
  'Open complaints': 'ဖွင့်ထားသော တိုင်ကြားချက်များ',
  'Customer complaint': 'ဖောက်သည် တိုင်ကြားချက်',
  'Sales vs Operational Leakage': 'ရောင်းအားနှင့် လုပ်ငန်းဆုံးရှုံးမှု နှိုင်းယှဉ်ချက်',
  'Void': 'ပယ်ဖျက်ဘေလ်',
  'Upcoming Feature': 'မကြာမီလာမည့် လုပ်ဆောင်ချက်',
  'This feature is not available yet.': 'ဤလုပ်ဆောင်ချက်ကို မရရှိနိုင်သေးပါ။',
  'OK': 'အိုကေ',
  'Total Sales Today': 'ယနေ့ ရောင်းအားစုစုပေါင်း',
  'Stock Health': 'ကုန်လက်ကျန် အခြေအနေ',
  'Tasks to Rate': 'အမှတ်ပေးရန် တာဝန်များ',
  'Submission': 'တင်ပြမှု',
  'Open Complaints': 'ဖွင့်ထားသော တိုင်ကြားချက်များ',
  'SOP': 'SOP',
  'Expected Outcome': 'မျှော်မှန်းရလဒ်',
  'YouTube URL': 'YouTube URL',
  'Enter a valid YouTube video URL.':
      'မှန်ကန်သော YouTube ဗီဒီယို URL ထည့်ပါ။',
  'English and Myanmar must use different YouTube videos.':
      'အင်္ဂလိပ်နှင့် မြန်မာအတွက် မတူညီသော YouTube ဗီဒီယိုများ အသုံးပြုရမည်။',
  'Update SOP?': 'SOP ကို ပြင်ဆင်မည်လား။',
  'Create SOP?': 'SOP ဖန်တီးမည်လား။',
  'This will save the edited SOP information.':
      'ပြင်ဆင်ထားသော SOP အချက်အလက်ကို သိမ်းဆည်းမည်။',
  'This will create a new SOP for the selected Stock tag.':
      'ရွေးထားသော ကုန်ပစ္စည်း Tag အတွက် SOP အသစ်တစ်ခု ဖန်တီးမည်။',
  'Example: Belly Pork Preparation': 'ဥပမာ - ဝက်ဗိုက်သား ပြင်ဆင်ခြင်း',
  'Title is required.': 'ခေါင်းစဉ် ဖြည့်ရန်လိုအပ်သည်။',
  'What should staff achieve after following this?':
      'ဤညွှန်ကြားချက်ကို လိုက်နာပြီးနောက် ဝန်ထမ်းက မည်သည့်ရလဒ် ရရှိသင့်သနည်း။',
  'Expected Outcome is required.': 'မျှော်မှန်းရလဒ် ဖြည့်ရန်လိုအပ်သည်။',
  'Describe the SOP content': 'SOP အကြောင်းအရာကို ဖော်ပြပါ',
  'Description is required.': 'ဖော်ပြချက် ဖြည့်ရန်လိုအပ်သည်။',
  'Search employee': 'ဝန်ထမ်း ရှာရန်',
  'Employee Status': 'ဝန်ထမ်း အခြေအနေ',
  'Searching...': 'ရှာဖွေနေသည်...',
  'Search Employees': 'ဝန်ထမ်းများ ရှာရန်',
  'People Audit': 'ဝန်ထမ်း စစ်ဆေးမှု',
  'Search an employee to view attendance history':
      'တက်ရောက်မှုမှတ်တမ်း ကြည့်ရန် ဝန်ထမ်းတစ်ဦးကို ရှာပါ',
  'Enter a name or employee ID, then tap Search Employees.':
      'အမည် သို့မဟုတ် ဝန်ထမ်း ID ထည့်ပြီး ဝန်ထမ်းများ ရှာရန်ကို နှိပ်ပါ။',
  'No employees found.': 'ဝန်ထမ်း မတွေ့ပါ။',
  'Employees': 'ဝန်ထမ်းများ',
  'Load More Employees': 'နောက်ထပ် ဝန်ထမ်းများ ရယူရန်',
  'Attendance Period': 'တက်ရောက်မှု ကာလ',
  'Day': 'နေ့',
  'Week': 'အပတ်',
  'Month': 'လ',
  'Year': 'နှစ်',
  'Present days': 'တက်ရောက်ရက်များ',
  'Missing out': 'အလုပ်ဆင်းချိန် မရှိ',
  'Completion': 'ပြီးစီးနှုန်း',
  'Total working': 'စုစုပေါင်း အလုပ်ချိန်',
  'Average / day': 'တစ်ရက် ပျမ်းမျှ',
  'Attendance Table': 'တက်ရောက်မှု ဇယား',
  'Confirmed working time includes completed Check In + Check Out records only.':
      'အတည်ပြုအလုပ်ချိန်တွင် အလုပ်ဝင်နှင့် အလုပ်ဆင်း မှတ်တမ်းပြည့်စုံသော ရက်များသာ ပါဝင်သည်။',
  'No attendance records in this period.':
      'ဤကာလအတွင်း တက်ရောက်မှုမှတ်တမ်း မရှိပါ။',
  'Attendance Events': 'တက်ရောက်မှု ဖြစ်စဉ်များ',
  'No attendance events in this period.':
      'ဤကာလအတွင်း တက်ရောက်မှု ဖြစ်စဉ် မရှိပါ။',
  'Date': 'ရက်စွဲ',
  'Check In': 'အလုပ်ဝင်',
  'Check Out': 'အလုပ်ဆင်း',
  'Working Time': 'အလုပ်ချိန်',
  'Annual Attendance Performance': 'နှစ်စဉ် တက်ရောက်မှု စွမ်းဆောင်ရည်',
  'Attendance reliability': 'တက်ရောက်မှု ပြည့်စုံနှုန်း',
  'Missing Check Outs': 'မမှတ်ထားသော အလုပ်ဆင်းချိန်များ',
  'Average working / completed day':
      'ပြီးစီးရက်အလိုက် ပျမ်းမျှ အလုပ်ချိန်',
  'Average Clock In': 'ပျမ်းမျှ အလုပ်ဝင်ချိန်',
  'Monthly Breakdown': 'လစဉ် အသေးစိတ်',
  'Tap a month to open its detailed payroll attendance view.':
      'လစာတွက်ချက်မှု တက်ရောက်မှုအသေးစိတ် ကြည့်ရန် လတစ်လကို နှိပ်ပါ။',
  'Present': 'တက်ရောက်',
  'Missing Out': 'အလုပ်ဆင်းချိန် မရှိ',
  'Hours': 'နာရီ',
  'Incomplete attendance': 'မပြည့်စုံသော တက်ရောက်မှု',
  'Only Owner, Head and Manager can generate attendance QR codes.':
      'Owner၊ Head နှင့် Manager သာ တက်ရောက်မှု QR ကုဒ် ဖန်တီးနိုင်သည်။',
  'Clock out completed': 'အလုပ်ဆင်း မှတ်တမ်းတင်ပြီး',
  'Clock in completed': 'အလုပ်ဝင် မှတ်တမ်းတင်ပြီး',
  'Location Services is off. Turn on Location Services to use Attendance.':
      'Location Services ပိတ်ထားသည်။ တက်ရောက်မှုကို အသုံးပြုရန် Location Services ကို ဖွင့်ပါ။',
  'Location permission denied. Allow location access to use Attendance.':
      'တည်နေရာ ခွင့်ပြုချက် ပယ်ချထားသည်။ တက်ရောက်မှုကို အသုံးပြုရန် တည်နေရာအသုံးပြုခွင့် ပေးပါ။',
  'Location permission permanently denied. Open app settings and allow location access.':
      'တည်နေရာ ခွင့်ပြုချက်ကို အမြဲတမ်းပိတ်ထားသည်။ အက်ပ်ဆက်တင်ကို ဖွင့်ပြီး တည်နေရာအသုံးပြုခွင့် ပေးပါ။',
  'Location service is off. Turn on Location Services to continue Attendance.':
      'တည်နေရာဝန်ဆောင်မှု ပိတ်ထားသည်။ တက်ရောက်မှု ဆက်လုပ်ရန် Location Services ကို ဖွင့်ပါ။',
  'Location permission is required to continue Attendance.':
      'တက်ရောက်မှု ဆက်လုပ်ရန် တည်နေရာ ခွင့်ပြုချက် လိုအပ်သည်။',
  'Location permission is permanently denied. Open app settings and allow location access.':
      'တည်နေရာ ခွင့်ပြုချက်ကို အမြဲတမ်းပိတ်ထားသည်။ အက်ပ်ဆက်တင်ကို ဖွင့်ပြီး တည်နေရာအသုံးပြုခွင့် ပေးပါ။',
  'Unable to capture the current GPS location. Please try again.':
      'လက်ရှိ GPS တည်နေရာကို မရယူနိုင်ပါ။ ထပ်မံကြိုးစားပါ။',
  'Location access required': 'တည်နေရာ အသုံးပြုခွင့် လိုအပ်သည်',
  'GPS location is required for attendance and is recorded with each Check In / Out.':
      'တက်ရောက်မှုအတွက် GPS တည်နေရာ လိုအပ်ပြီး အလုပ်ဝင်/အလုပ်ဆင်း တစ်ကြိမ်စီတွင် မှတ်တမ်းတင်သည်။',
  'Location Settings': 'တည်နေရာ ဆက်တင်များ',
  'App Settings': 'အက်ပ် ဆက်တင်များ',
  'Select an attendance action. Data is loaded only when requested.':
      'တက်ရောက်မှု လုပ်ဆောင်ချက်ကို ရွေးပါ။ တောင်းဆိုသည့်အခါမှသာ ဒေတာရယူမည်။',
  'Check In / Out': 'အလုပ်ဝင် / အလုပ်ဆင်း',
  'Load today\'s attendance, then scan the required QR code.':
      'ယနေ့ တက်ရောက်မှုကို ရယူပြီး လိုအပ်သော QR ကုဒ်ကို စကန်ဖတ်ပါ။',
  'QR Code': 'QR ကုဒ်',
  'Generate a 30-minute Check In or Check Out QR code.':
      'မိနစ် ၃၀ သက်တမ်းရှိ အလုပ်ဝင် သို့မဟုတ် အလုပ်ဆင်း QR ကုဒ် ဖန်တီးပါ။',
  'Owner, Head or Manager permission is required.':
      'Owner၊ Head သို့မဟုတ် Manager ခွင့်ပြုချက် လိုအပ်သည်။',
  'Completed for today': 'ယနေ့အတွက် ပြီးစီးပြီ',
  'Checked in · ready to check out': 'အလုပ်ဝင်ပြီး · အလုပ်ဆင်းရန် အသင့်',
  'Not checked in': 'အလုပ်မဝင်ရသေး',
  'GPS location and a valid attendance QR are required.':
      'GPS တည်နေရာနှင့် မှန်ကန်သော တက်ရောက်မှု QR လိုအပ်သည်။',
  'Already checked in today.': 'ယနေ့ အလုပ်ဝင်ပြီးသားဖြစ်သည်။',
  'Scan a valid Check In QR code.': 'မှန်ကန်သော အလုပ်ဝင် QR ကုဒ်ကို စကန်ဖတ်ပါ။',
  'Already checked out today.': 'ယနေ့ အလုပ်ဆင်းပြီးသားဖြစ်သည်။',
  'Scan a valid Check Out QR code.': 'မှန်ကန်သော အလုပ်ဆင်း QR ကုဒ်ကို စကန်ဖတ်ပါ။',
  'Available after Check In.': 'အလုပ်ဝင်ပြီးနောက် အသုံးပြုနိုင်သည်။',
  'Attendance QR Code': 'တက်ရောက်မှု QR ကုဒ်',
  'Select the action first, then press Generate QR. Each QR works for any employee in this business for 30 minutes.':
      'လုပ်ဆောင်ချက်ကို ဦးစွာရွေးပြီး QR ဖန်တီးရန်ကို နှိပ်ပါ။ QR တစ်ခုစီကို ဤလုပ်ငန်းရှိ ဝန်ထမ်းတိုင်း မိနစ် ၃၀ ကြာ အသုံးပြုနိုင်သည်။',
  'QR Action': 'QR လုပ်ဆောင်ချက်',
  'Generating...': 'ဖန်တီးနေသည်...',
  'Generate QR': 'QR ဖန်တီးရန်',
  'Generate New QR': 'QR အသစ် ဖန်တီးရန်',
  'Expired': 'သက်တမ်းကုန်',
  'This QR has expired. Generate a new QR to continue.':
      'ဤ QR သက်တမ်းကုန်ပြီ။ ဆက်လုပ်ရန် QR အသစ် ဖန်တီးပါ။',
  'Clock In': 'အလုပ်ဝင်',
  'Clock Out': 'အလုပ်ဆင်း',
  'Approved.': 'အတည်ပြုပြီး။',
  'Rejected.': 'ပယ်ချပြီး။',
  'Selected records approved': 'ရွေးထားသော မှတ်တမ်းများ အတည်ပြုပြီး',
  'Selected records rejected': 'ရွေးထားသော မှတ်တမ်းများ ပယ်ချပြီး',
  'Approve Receiving Record?': 'ကုန်လက်ခံမှတ်တမ်းကို အတည်ပြုမည်လား။',
  'Reject Receiving Record?': 'ကုန်လက်ခံမှတ်တမ်းကို ပယ်ချမည်လား။',
  'This will update the review status of this receiving record.':
      'ဤကုန်လက်ခံမှတ်တမ်း၏ စစ်ဆေးမှုအခြေအနေကို ပြင်ဆင်မည်။',
  'Approve Daily Count?': 'နေ့စဉ်ရေတွက်မှုကို အတည်ပြုမည်လား။',
  'Reject Daily Count?': 'နေ့စဉ်ရေတွက်မှုကို ပယ်ချမည်လား။',
  'This will update the review status of this daily stock count.':
      'ဤနေ့စဉ်ကုန်လက်ကျန်ရေတွက်မှု၏ စစ်ဆေးမှုအခြေအနေကို ပြင်ဆင်မည်။',
  'This will update all selected records.':
      'ရွေးထားသော မှတ်တမ်းအားလုံးကို ပြင်ဆင်မည်။',
  'Search Again': 'ထပ်မံ ရှာရန်',
  'No records are loaded by default. Select Status and Date, then press Search.':
      'ပုံမှန်အားဖြင့် မှတ်တမ်းမရယူထားပါ။ အခြေအနေနှင့် ရက်စွဲကို ရွေးပြီး ရှာရန်ကို နှိပ်ပါ။',
  'No daily count records found.': 'နေ့စဉ်ရေတွက်မှု မှတ်တမ်း မတွေ့ပါ။',
  'Details': 'အသေးစိတ်',
  'changed to': 'ပြောင်းလဲထားသည့်တန်ဖိုး',
  'Fixed EastApp role hierarchy': 'သတ်မှတ်ထားသော EastApp ရာထူးအဆင့်ဆင့်',
  'No role found': 'ရာထူး မတွေ့ပါ',
  'Owner → Head → Manager → Supervisor → Staff1 → Staff2. Roles are fixed and cannot be created, renamed or deleted.':
      'Owner → Head → Manager → Supervisor → Staff1 → Staff2။ ရာထူးများကို သတ်မှတ်ထားပြီး ဖန်တီးခြင်း၊ အမည်ပြောင်းခြင်း သို့မဟုတ် ဖျက်ခြင်း မပြုနိုင်ပါ။',
  'Refresh': 'ပြန်လည်ရယူရန်',
  'No user found': 'အသုံးပြုသူ မတွေ့ပါ',
  'Last': 'နောက်ဆုံး',
  'Coming soon. User setup is enabled first.':
      'မကြာမီ ရရှိမည်။ အသုံးပြုသူ စီမံမှုကို ဦးစွာ ဖွင့်ထားသည်။',
  'Deactivate User': 'အသုံးပြုသူကို ပိတ်ရန်',
  'Deactivate User?': 'အသုံးပြုသူကို ပိတ်မည်လား။',
  'This will set the user to inactive using the selected last working date.':
      'ရွေးထားသော နောက်ဆုံးအလုပ်ရက်ဖြင့် အသုံးပြုသူကို Inactive အဖြစ် သတ်မှတ်မည်။',
  'User set to inactive': 'အသုံးပြုသူကို Inactive အဖြစ် သတ်မှတ်ပြီး',
  'Status will be set to Inactive and all sessions will be revoked.':
      'အခြေအနေကို Inactive အဖြစ် သတ်မှတ်ပြီး session အားလုံးကို ရုပ်သိမ်းမည်။',
  'Set User Inactive': 'အသုံးပြုသူကို Inactive သတ်မှတ်ရန်',
  'Update User?': 'အသုံးပြုသူကို ပြင်ဆင်မည်လား။',
  'Create User?': 'အသုံးပြုသူ ဖန်တီးမည်လား။',
  'This will assign Owner access and a separate employee ID in every business.':
      'လုပ်ငန်းတိုင်းတွင် Owner အသုံးပြုခွင့်နှင့် သီးခြားဝန်ထမ်း ID တစ်ခု သတ်မှတ်မည်။',
  'This will update the selected user account and access settings.':
      'ရွေးထားသော အသုံးပြုသူအကောင့်နှင့် အသုံးပြုခွင့် ဆက်တင်များကို ပြင်ဆင်မည်။',
  'User updated': 'အသုံးပြုသူ ပြင်ဆင်ပြီး',
  'User created': 'အသုံးပြုသူ ဖန်တီးပြီး',
  'Edit User': 'အသုံးပြုသူ ပြင်ဆင်ရန်',
  'Employee ID will be generated automatically by this business.':
      'ဤလုပ်ငန်းက ဝန်ထမ်း ID ကို အလိုအလျောက် ဖန်တီးပေးမည်။',
  'New Password (Optional)': 'စကားဝှက်အသစ် (ရွေးချယ်နိုင်)',
  'Minimum 4 characters': 'အနည်းဆုံး စာလုံး ၄ လုံး',
  'Required for a new person; blank for an existing login':
      'လူသစ်အတွက် လိုအပ်သည်။ ရှိပြီးသား login ဖြစ်ပါက အလွတ်ထားပါ',
  'When the phone number already belongs to an application login, the same profile and password are reused and only a new employee ID is created for this business.':
      'ဖုန်းနံပါတ်သည် အက်ပ် login တစ်ခုနှင့် ချိတ်ထားပြီးသားဖြစ်ပါက အချက်အလက်နှင့် စကားဝှက်ကို ပြန်သုံးပြီး ဤလုပ်ငန်းအတွက် ဝန်ထမ်း ID အသစ်သာ ဖန်တီးမည်။',
  'Full Name': 'အမည်အပြည့်အစုံ',
  'Example: Nicky Chang': 'ဥပမာ - Nicky Chang',
  'Born Date': 'မွေးသက္ကရာဇ်',
  'Loading roles for this business...': 'ဤလုပ်ငန်း၏ ရာထူးများကို ရယူနေသည်...',
  'Start Date': 'စတင်ရက်',
  'End Date (Optional)': 'ပြီးဆုံးရက် (ရွေးချယ်နိုင်)',
  'Not set': 'မသတ်မှတ်ရသေး',
  'Save Changes': 'ပြောင်းလဲမှုများ သိမ်းရန်',
  'Save User': 'အသုံးပြုသူ သိမ်းရန်',
  'Full Name required': 'အမည်အပြည့်အစုံ လိုအပ်သည်',
  'Born Date required': 'မွေးသက္ကရာဇ် လိုအပ်သည်',
  'Phone Number required': 'ဖုန်းနံပါတ် လိုအပ်သည်',
  'Enter a valid phone number': 'မှန်ကန်သော ဖုန်းနံပါတ် ထည့်ပါ',
  'Loading roles': 'ရာထူးများကို ရယူနေသည်',
  'Active Role required': 'အသုံးပြုနေသော ရာထူး လိုအပ်သည်',
  'Select status': 'အခြေအနေ ရွေးပါ',
  'Select role': 'ရာထူး ရွေးပါ',
  'Last Working Date': 'နောက်ဆုံး အလုပ်ရက်',
  'Inactive': 'အသုံးမပြုနေ',
  'Action taken': 'လုပ်ဆောင်ခဲ့မှု',
  'Add Complaint': 'တိုင်ကြားချက် ထည့်ရန်',
  'Add Waste Record': 'စွန့်ပစ်မှုမှတ်တမ်း ထည့်ရန်',
  'Age': 'အသက်',
  'All reports reviewed': 'အစီရင်ခံစာအားလုံး စစ်ဆေးပြီး',
  'Any unsaved values on this screen will be replaced.':
      'ဤစာမျက်နှာရှိ မသိမ်းရသေးသော တန်ဖိုးများကို အစားထိုးမည်။',
  'Bill Number': 'ဘေလ်နံပါတ်',
  'Bulk submission is risky. Check every record. This action cannot be undone.':
      'အစုလိုက်တင်ပြခြင်းတွင် အန္တရာယ်ရှိသည်။ မှတ်တမ်းတိုင်းကို စစ်ဆေးပါ။ ဤလုပ်ဆောင်ချက်ကို ပြန်ပြင်၍မရပါ။',
  'Camera': 'ကင်မရာ',
  'Carousel position': 'Carousel နေရာ',
  'Cash Received By': 'ငွေလက်ခံသူ',
  'Complaint Information': 'တိုင်ကြားချက် အချက်အလက်',
  'Complaint report created': 'တိုင်ကြားချက်အစီရင်ခံစာ ဖန်တီးပြီး',
  'Complaint updated': 'တိုင်ကြားချက် ပြင်ဆင်ပြီး',
  'Complete all pending items': 'စောင့်ဆိုင်းနေသော ပစ္စည်းအားလုံးကို ပြီးစီးပါ',
  'Copy': 'ကူးယူရန်',
  'Copy SKUs from Business': 'လုပ်ငန်းမှ SKU များ ကူးယူရန်',
  'Copy from another business': 'အခြားလုပ်ငန်းမှ ကူးယူရန်',
  'Copy selected SKUs with their tags and suppliers.':
      'ရွေးထားသော SKU များကို Tag နှင့် ပေးသွင်းသူများအပါအဝင် ကူးယူပါ။',
  'Customer Gender': 'ဖောက်သည် လိင်',
  'Daily Sales Input': 'နေ့စဉ် အရောင်းထည့်သွင်းမှု',
  'Daily photos submitted': 'နေ့စဉ်ဓာတ်ပုံများ တင်ပြပြီး',
  'Delete Advertisement?': 'ကြော်ငြာကို ဖျက်မည်လား။',
  'End date & time *': 'ပြီးဆုံးရက်နှင့် အချိန် *',
  'End date and time must be later than start date and time.':
      'ပြီးဆုံးရက်နှင့် အချိန်သည် စတင်ရက်နှင့် အချိန်နောက်ပိုင်း ဖြစ်ရမည်။',
  'Enter the full platform amount. EastApp includes 60% in Total Sales and estimates 40% as platform commission.':
      'ပလက်ဖောင်းပမာဏအပြည့်ကို ထည့်ပါ။ EastApp သည် ရောင်းအားစုစုပေါင်းတွင် ၆၀% ထည့်တွက်ပြီး ၄၀% ကို ပလက်ဖောင်းကော်မရှင်အဖြစ် ခန့်မှန်းသည်။',
  'Estimated Age': 'ခန့်မှန်းအသက်',
  'Explain why the bill was voided': 'ဘေလ်ပယ်ဖျက်ရသည့် အကြောင်းရင်းကို ရှင်းပြပါ',
  'Female': 'အမျိုးသမီး',
  'Gallery': 'ဓာတ်ပုံများ',
  'Gender': 'လိင်',
  'Google Maps': 'Google Maps',
  'Google rating unavailable': 'Google အဆင့်သတ်မှတ်ချက် မရနိုင်ပါ',
  'Image, start date/time and end date/time are compulsory.':
      'ပုံ၊ စတင်ရက်/အချိန်နှင့် ပြီးဆုံးရက်/အချိန်တို့ကို မဖြစ်မနေ ဖြည့်ပါ။',
  'Inventory Health': 'ကုန်လက်ကျန် အခြေအနေ',
  'Item': 'ပစ္စည်း',
  'Item name': 'ပစ္စည်းအမည်',
  'Male': 'အမျိုးသား',
  'No advertisements yet.': 'ကြော်ငြာ မရှိသေးပါ။',
  'No caption needed. Take at least five operational photos each day.':
      'စာတန်းမလိုပါ။ နေ့စဉ် လုပ်ငန်းဓာတ်ပုံ အနည်းဆုံး ၅ ပုံ ရိုက်ပါ။',
  'No checklist set.': 'စစ်ဆေးစာရင်း မသတ်မှတ်ရသေးပါ။',
  'No complaints recorded': 'တိုင်ကြားချက် မှတ်တမ်းမရှိပါ',
  'No inventory risks detected': 'ကုန်လက်ကျန်အန္တရာယ် မတွေ့ပါ',
  'No photos taken today': 'ယနေ့ ဓာတ်ပုံ မရိုက်ရသေးပါ',
  'No submitted Sales reports in this date range':
      'ဤရက်အပိုင်းအခြားတွင် တင်ပြထားသော အရောင်းအစီရင်ခံစာ မရှိပါ',
  'No void bills recorded.': 'ပယ်ဖျက်ဘေလ် မှတ်တမ်းမရှိပါ။',
  'No waste records yet': 'စွန့်ပစ်မှုမှတ်တမ်း မရှိသေးပါ',
  'Non-SKU item': 'SKU မဟုတ်သော ပစ္စည်း',
  'Only active advertisements publish during their schedule.':
      'အသုံးပြုနေသော ကြော်ငြာများသာ သတ်မှတ်ချိန်အတွင်း ပြသမည်။',
  'Open': 'ဖွင့်ထား',
  'Optional': 'ရွေးချယ်နိုင်',
  'Optional stock item': 'ကုန်ပစ္စည်း (ရွေးချယ်နိုင်)',
  'Other': 'အခြား',
  'Position': 'နေရာ',
  'Priority Risks': 'ဦးစားပေး အန္တရာယ်များ',
  'Proceed': 'ဆက်လုပ်ရန်',
  'Quantity': 'အရေအတွက်',
  'Reason': 'အကြောင်းရင်း',
  'Recent Waste Evidence': 'မကြာသေးမီ စွန့်ပစ်မှု အထောက်အထား',
  'Record': 'မှတ်တမ်းတင်ရန်',
  'Record Void Bill': 'ပယ်ဖျက်ဘေလ် မှတ်တမ်းတင်ရန်',
  'Record this void bill?': 'ဤပယ်ဖျက်ဘေလ်ကို မှတ်တမ်းတင်မည်လား။',
  'Refresh loaded range': 'ရယူထားသော ရက်အပိုင်းအခြားကို ပြန်လည်ရယူရန်',
  'Replace Photo': 'ဓာတ်ပုံ အစားထိုးရန်',
  'Replace SKU Photo': 'SKU ဓာတ်ပုံ အစားထိုးရန်',
  'Report Date': 'အစီရင်ခံရက်',
  'Report evidence could not be loaded.': 'အစီရင်ခံစာ အထောက်အထားကို မရယူနိုင်ပါ။',
  'Resolved': 'ဖြေရှင်းပြီး',
  'Retry Camera': 'ကင်မရာ ထပ်ကြိုးစားရန်',
  'Sales Report Loader': 'အရောင်းအစီရင်ခံစာ ရယူရန်',
  'Sales Submission Details': 'အရောင်းတင်ပြမှု အသေးစိတ်',
  'Sales report submitted': 'အရောင်းအစီရင်ခံစာ တင်ပြပြီး',
  'Search source SKU': 'မူရင်း SKU ရှာရန်',
  'Select Sales report dates': 'အရောင်းအစီရင်ခံစာ ရက်များရွေးပါ',
  'Select a date range, then tap Load Report.':
      'ရက်အပိုင်းအခြား ရွေးပြီး အစီရင်ခံစာ ရယူရန်ကို နှိပ်ပါ။',
  'Select a maximum of 30 days.': 'အများဆုံး ရက် ၃၀ ရွေးပါ။',
  'Select up to 30 days, then load submitted reports.':
      'ရက် ၃၀ အထိ ရွေးပြီး တင်ပြထားသော အစီရင်ခံစာများကို ရယူပါ။',
  'Source business': 'မူရင်းလုပ်ငန်း',
  'Start date & time *': 'စတင်ရက်နှင့် အချိန် *',
  'Submission Details': 'တင်ပြမှု အသေးစိတ်',
  'Submit Complaint': 'တိုင်ကြားချက် တင်ပြရန်',
  'Submit Waste Report': 'စွန့်ပစ်မှုအစီရင်ခံစာ တင်ပြရန်',
  'Submit customer complaint?': 'ဖောက်သည် တိုင်ကြားချက်ကို တင်ပြမည်လား။',
  'Submit daily photo batch?': 'နေ့စဉ်ဓာတ်ပုံအစုကို တင်ပြမည်လား။',
  'Submit sales report for approval?': 'အရောင်းအစီရင်ခံစာကို အတည်ပြုရန် တင်ပြမည်လား။',
  'Submit waste report?': 'စွန့်ပစ်မှုအစီရင်ခံစာကို တင်ပြမည်လား။',
  'Switch sales report date?': 'အရောင်းအစီရင်ခံရက် ပြောင်းမည်လား။',
  'Tap to edit': 'ပြင်ရန် နှိပ်ပါ',
  'This advertisement will be removed permanently.': 'ဤကြော်ငြာကို အပြီးတိုင် ဖျက်မည်။',
  'Total Sales is calculated by the server: Cash Total + eWallet Total + 60% of Gross Food Delivery Sales.':
      'ဆာဗာက ရောင်းအားစုစုပေါင်းကို ငွေသားစုစုပေါင်း + eWallet စုစုပေါင်း + Food Delivery ရောင်းအားစုစုပေါင်း၏ ၆၀% ဖြင့် တွက်ချက်သည်။',
  'Unknown': 'မသိ',
  'Until': 'အထိ',
  'Update': 'ပြင်ဆင်ရန်',
  'Update Complaint': 'တိုင်ကြားချက် ပြင်ဆင်ရန်',
  'Update complaint status?': 'တိုင်ကြားချက်အခြေအနေ ပြင်ဆင်မည်လား။',
  'Use Range': 'ရက်အပိုင်းအခြား အသုံးပြုရန်',
  'Use a wide banner image. Recommended ratio: 3.45:1.':
      'အလျားကျယ် banner ပုံ အသုံးပြုပါ။ အကြံပြုအချိုး 3.45:1။',
  'Void Bills': 'ပယ်ဖျက်ဘေလ်များ',
  'Void Bills (Optional)': 'ပယ်ဖျက်ဘေလ်များ (ရွေးချယ်နိုင်)',
  'Void bill created': 'ပယ်ဖျက်ဘေလ် ဖန်တီးပြီး',
  'Void bill recorded': 'ပယ်ဖျက်ဘေလ် မှတ်တမ်းတင်ပြီး',
  'Waste report submitted': 'စွန့်ပစ်မှုအစီရင်ခံစာ တင်ပြပြီး',
  'What action was taken?': 'မည်သည့်လုပ်ဆောင်မှု ပြုလုပ်ခဲ့သနည်း။',
  'What did the customer complain about?': 'ဖောက်သည်က မည်သည့်အကြောင်း တိုင်ကြားခဲ့သနည်း။',
  'Why was this item wasted?': 'ဤပစ္စည်းကို အဘယ်ကြောင့် စွန့်ပစ်ခဲ့သနည်း။',
  'e.g. V-001283': 'ဥပမာ V-001283',
  'kg / pcs': 'kg / pcs',
  'Take a clear photo of the void bill.': 'ပယ်ဖျက်ဘေလ်ကို ရှင်းလင်းစွာ ဓာတ်ပုံရိုက်ပါ။',
  'Bill number is compulsory.': 'ဘေလ်နံပါတ် မဖြစ်မနေ ဖြည့်ပါ။',
  'This bill number is already recorded.': 'ဤဘေလ်နံပါတ်ကို မှတ်တမ်းတင်ပြီးသား ဖြစ်သည်။',
  'Void reason is compulsory.': 'ပယ်ဖျက်ရသည့်အကြောင်းရင်း မဖြစ်မနေ ဖြည့်ပါ။',
  'Enter a valid void amount.': 'မှန်ကန်သော ပယ်ဖျက်ပမာဏ ထည့်ပါ။',
  'Expand only when a bill was voided.': 'ဘေလ်ပယ်ဖျက်ထားသည့်အခါမှသာ ဤအပိုင်းကို ဖွင့်ပါ။',
  'Cash Total, Gross Food Delivery Sales and eWallet Total are required. Enter 0 when a payment channel has no sales.':
      'ငွေသားစုစုပေါင်း၊ Food Delivery ရောင်းအားစုစုပေါင်းနှင့် eWallet စုစုပေါင်းတို့ကို မဖြစ်မနေ ဖြည့်ပါ။ ငွေပေးချေမှုနည်းလမ်းတစ်ခုတွင် ရောင်းအားမရှိပါက 0 ထည့်ပါ။',
  'Payment totals must be valid non-negative amounts.':
      'ငွေပေးချေမှု စုစုပေါင်းများသည် မှန်ကန်ပြီး အနုတ်မဖြစ်သော ပမာဏများ ဖြစ်ရမည်။',
  'Cash Received By is required.': 'ငွေလက်ခံသူ မဖြစ်မနေ ဖြည့်ပါ။',
  'Staff on Duty is required and must be at least 1.':
      'တာဝန်ကျဝန်ထမ်းကို မဖြစ်မနေ ဖြည့်ပြီး အနည်းဆုံး ၁ ယောက် ရှိရမည်။',
  'Finish recording this void bill, or clear the optional fields before submitting Sales.':
      'အရောင်းတင်ပြမီ ဤပယ်ဖျက်ဘေလ်ကို မှတ်တမ်းတင်ပြီးစီးပါ သို့မဟုတ် ရွေးချယ်နိုင်သော အကွက်များကို ရှင်းပါ။',
  'Take a clear waste photo.': 'စွန့်ပစ်ပစ္စည်းကို ရှင်းလင်းစွာ ဓာတ်ပုံရိုက်ပါ။',
  'Select a SKU or enter the item name.': 'SKU တစ်ခု ရွေးပါ သို့မဟုတ် ပစ္စည်းအမည် ထည့်ပါ။',
  'Enter a valid waste quantity.': 'မှန်ကန်သော စွန့်ပစ်အရေအတွက် ထည့်ပါ။',
  'Unit is compulsory.': 'ယူနစ်ကို မဖြစ်မနေ ဖြည့်ပါ။',
  'Enter a valid estimated unit cost.': 'မှန်ကန်သော ခန့်မှန်းတစ်ယူနစ်ကုန်ကျစရိတ် ထည့်ပါ။',
  'Waste reason is compulsory.': 'စွန့်ပစ်ရသည့်အကြောင်းရင်း မဖြစ်မနေ ဖြည့်ပါ။',
  'Take a complaint photo.': 'တိုင်ကြားချက်အထောက်အထားကို ရှင်းလင်းစွာ ဓာတ်ပုံရိုက်ပါ။',
  'Enter an estimated age from 1 to 120.': 'ခန့်မှန်းအသက် ၁ မှ ၁၂၀ အတွင်း ထည့်ပါ။',
  'Complaint information is compulsory.': 'တိုင်ကြားချက်အချက်အလက် မဖြစ်မနေ ဖြည့်ပါ။',
  'Action taken is compulsory.': 'လုပ်ဆောင်ခဲ့မှု မဖြစ်မနေ ဖြည့်ပါ။',
  'Compensation cannot be negative.': 'လျော်ကြေးပမာဏသည် အနုတ်မဖြစ်ရပါ။',
  'Enter an action and valid compensation amount.':
      'လုပ်ဆောင်ခဲ့မှုနှင့် မှန်ကန်သော လျော်ကြေးပမာဏ ထည့်ပါ။',
  'Minimum achieved': 'အနည်းဆုံးလိုအပ်ချက် ပြည့်မီပြီ',
  'Approve Report': 'အစီရင်ခံစာ အတည်ပြုရန်',
  'Reject Report': 'အစီရင်ခံစာ ပယ်ချရန်',
  'Optional approval note': 'အတည်ပြုမှတ်ချက် (ရွေးချယ်နိုင်)',
  'Rejection reason is compulsory': 'ပယ်ချရသည့်အကြောင်းရင်း မဖြစ်မနေ ဖြည့်ပါ',
  'Approve this report?': 'ဤအစီရင်ခံစာကို အတည်ပြုမည်လား။',
  'Reject this report?': 'ဤအစီရင်ခံစာကို ပယ်ချမည်လား။',
  'Report approved': 'အစီရင်ခံစာ အတည်ပြုပြီး',
  'Report rejected': 'အစီရင်ခံစာ ပယ်ချပြီး',
  'Tap to retake': 'ပြန်ရိုက်ရန် နှိပ်ပါ',
  'Void Bill Photo': 'ပယ်ဖျက်ဘေလ် ဓာတ်ပုံ',
  'Waste Photo': 'စွန့်ပစ်ပစ္စည်း ဓာတ်ပုံ',
  'Complaint Photo': 'တိုင်ကြားချက် ဓာတ်ပုံ',
  'Photo evidence is compulsory for every waste record.':
      'စွန့်ပစ်မှုမှတ်တမ်းတိုင်းအတွက် ဓာတ်ပုံအထောက်အထား မဖြစ်မနေ လိုအပ်သည်။',
  'Capture the full bill including number and amount.':
      'ဘေလ်နံပါတ်နှင့် ပမာဏအပါအဝင် ဘေလ်တစ်ခုလုံးကို ရိုက်ယူပါ။',
  'Capture relevant evidence while respecting customer privacy.':
      'ဖောက်သည်၏ ကိုယ်ရေးလုံခြုံမှုကို လေးစား၍ သက်ဆိုင်ရာ အထောက်အထားကို ရိုက်ယူပါ။',
  'Gross Food Delivery Sales': 'Food Delivery ရောင်းအားစုစုပေါင်း',
  'Estimated Unit Cost': 'ခန့်မှန်း တစ်ယူနစ်ကုန်ကျစရိတ်',
  'Compensation Amount (Optional)': 'လျော်ကြေးပမာဏ (ရွေးချယ်နိုင်)',
  'Compensation Amount': 'လျော်ကြေးပမာဏ',
  'Critical': 'အလွန်အရေးကြီး',
  'High': 'မြင့်',
  'Overstock': 'ကုန်လက်ကျန်ပို',
  'Daily Photo': 'နေ့စဉ်ဓာတ်ပုံ',
  'Create Advertisement': 'ကြော်ငြာ ဖန်တီးရန်',
  'Edit Advertisement': 'ကြော်ငြာ ပြင်ဆင်ရန်',
  'Upload advertisement image': 'ကြော်ငြာပုံ တင်ရန်',
  'Replace image': 'ပုံ အစားထိုးရန်',
  'Save Advertisement': 'ကြော်ငြာ သိမ်းရန်',
  'Published': 'ပြသနေသည်',
  'Scheduled': 'အချိန်သတ်မှတ်ထားသည်',
  'No other business is available.': 'အခြားလုပ်ငန်း မရှိပါ။',
  'Clear visible': 'မြင်ရသောရွေးချယ်မှုများ ရှင်းရန်',
  'Select visible': 'မြင်ရသောပစ္စည်းများ ရွေးရန်',
  'Copying…': 'ကူးယူနေသည်…',
  'The photo, customer estimate, complaint and action will be stored for business review.':
      'ဓာတ်ပုံ၊ ဖောက်သည်ခန့်မှန်းချက်၊ တိုင်ကြားချက်နှင့် လုပ်ဆောင်မှုကို လုပ်ငန်းစစ်ဆေးရန် သိမ်းဆည်းမည်။',
  'Take a clear photo of the SKU.': 'SKU ကို ရှင်းလင်းစွာ ဓာတ်ပုံရိုက်ပါ။',
  'Void Amount': 'ပယ်ဖျက်ပမာဏ',
  '30-day Loss': 'ရက် ၃၀ ဆုံးရှုံးမှု',
  'Records': 'မှတ်တမ်းများ',
  'Waste Evidence': 'စွန့်ပစ်မှု အထောက်အထား',
  'Technical Error': 'နည်းပညာဆိုင်ရာ အမှား',
  'Error details copied': 'အမှားအသေးစိတ်ကို ကူးယူပြီး',
  'Please review the information carefully. This will change business data.':
      'အချက်အလက်ကို သေချာစစ်ဆေးပါ။ ဤလုပ်ဆောင်ချက်သည် လုပ်ငန်းဒေတာကို ပြောင်းလဲမည်။',
  'Help': 'အကူအညီ',
  'Logout': 'ထွက်ရန်',
  'No ratings yet': 'အဆင့်သတ်မှတ်ချက် မရှိသေးပါ',
  'Delete Selected SOP?': 'ရွေးထားသော SOP ကို ဖျက်မည်လား။',
  'Submitted count': 'ရေတွက်မှု တင်ပြပြီး',
  'Reviewed count': 'ရေတွက်မှု စစ်ဆေးပြီး',
  'Created task': 'တာဝန် ဖန်တီးပြီး',
  'Debug report copied': 'Debug အစီရင်ခံစာ ကူးယူပြီး',
  'Copy Debug Report': 'Debug အစီရင်ခံစာ ကူးယူရန်',
  'Ask the tester to paste this report into WhatsApp when something fails inside the app.':
      'အက်ပ်အတွင်း ပြဿနာဖြစ်ပါက ဤအစီရင်ခံစာကို WhatsApp တွင် ကူးထည့်ပေးရန် စမ်းသပ်သူကို ပြောပါ။',
  'Report preview': 'အစီရင်ခံစာ အစမ်းမြင်ကွင်း',
  'Select an active user.': 'အသုံးပြုနေသော အသုံးပြုသူတစ်ဦး ရွေးပါ။',
  'Choose at least +1 or -1 point.': 'အနည်းဆုံး +1 သို့မဟုတ် -1 ပွိုင့် ရွေးပါ။',
  'Reason is compulsory.': 'အကြောင်းရင်း မဖြစ်မနေ ဖြည့်ပါ။',
  'Confirm point adjustment': 'ပွိုင့်ပြင်ဆင်မှု အတည်ပြုရန်',
  'Points updated': 'ပွိုင့်များ ပြင်ဆင်ပြီး',
  'Point Adjustment': 'ပွိုင့် ပြင်ဆင်မှု',
  'Active User': 'အသုံးပြုနေသော အသုံးပြုသူ',
  'Decrease 1 point': '၁ ပွိုင့် လျှော့ရန်',
  'Add 1 point': '၁ ပွိုင့် ထည့်ရန်',
  'Reason *': 'အကြောင်းရင်း *',
  'Compulsory reason for this adjustment': 'ဤပြင်ဆင်မှုအတွက် မဖြစ်မနေ ဖြည့်ရမည့် အကြောင်းရင်း',
  'Apply Adjustment': 'ပြင်ဆင်မှု အတည်ပြုရန်',
  'Current Business Ranking': 'လက်ရှိလုပ်ငန်း အဆင့်သတ်မှတ်ချက်',
  'No active users found.': 'အသုံးပြုနေသော အသုံးပြုသူ မတွေ့ပါ။',
  'Enter the 10-character Setup Code shown by EastApp.':
      'EastApp တွင် ပြထားသော စာလုံး ၁၀ လုံးပါ Setup Code ကို ထည့်ပါ။',
  'Initial Setup Code': 'ကနဦး Setup Code',
  'Copy this one-time code. It is available only before Initial Setup is completed.':
      'ဤတစ်ကြိမ်သုံးကုဒ်ကို ကူးယူပါ။ Initial Setup မပြီးမီသာ အသုံးပြုနိုင်ပါသည်။',
  'Valid until': 'သက်တမ်းကုန်ချိန်',
  'Copy Code': 'ကုဒ်ကူးယူရန်',
  'Show Setup Code': 'Setup Code ပြရန်',
  'Setup Code copied.': 'Setup Code ကူးယူပြီး။',
  'Company Code must contain 2–32 letters, numbers, _ or -.':
      'Company Code တွင် စာလုံး၊ ဂဏန်း၊ _ သို့မဟုတ် - စုစုပေါင်း ၂ မှ ၃၂ လုံး ပါရမည်။',
  'Employee ID Prefix must contain 1–3 letters.':
      'ဝန်ထမ်း ID Prefix တွင် စာလုံး ၁ မှ ၃ လုံး ပါရမည်။',
  'Select the Google business location.': 'Google လုပ်ငန်းတည်နေရာကို ရွေးပါ။',
  'Password must contain at least 4 characters.': 'စကားဝှက်တွင် အနည်းဆုံး စာလုံး ၄ လုံး ပါရမည်။',
  'Passwords do not match.': 'စကားဝှက်များ မကိုက်ညီပါ။',
  'Complete Initial Setup?': 'ကနဦးသတ်မှတ်မှုကို ပြီးစီးမည်လား။',
  'This will create the first business and Owner account. The selected Google location will be used as the office reference for attendance distance.':
      'ပထမလုပ်ငန်းနှင့် Owner အကောင့်ကို ဖန်တီးမည်။ ရွေးထားသော Google တည်နေရာကို တက်ရောက်မှုအကွာအဝေးအတွက် အလုပ်နေရာအညွှန်းအဖြစ် အသုံးပြုမည်။',
  'Owner Account Created': 'Owner အကောင့် ဖန်တီးပြီး',
  'Use the Company Code, Employee ID and password to sign in.':
      'ဝင်ရောက်ရန် Company Code၊ ဝန်ထမ်း ID နှင့် စကားဝှက်ကို အသုံးပြုပါ။',
  'Continue to Login': 'Login သို့ ဆက်ရန်',
  'Initial Setup': 'ကနဦး သတ်မှတ်မှု',
  'Create the first business and Owner account. Employee ID is generated automatically.':
      'ပထမလုပ်ငန်းနှင့် Owner အကောင့်ကို ဖန်တီးပါ။ ဝန်ထမ်း ID ကို အလိုအလျောက် ဖန်တီးပေးမည်။',
  'Setup Code': 'Setup Code',
  '10-character code': 'စာလုံး ၁၀ လုံးပါ ကုဒ်',
  'Business Name': 'လုပ်ငန်းအမည်',
  'Example: The East': 'ဥပမာ - The East',
  'Company Code': 'ကုမ္ပဏီကုဒ်',
  'Example: EAST': 'ဥပမာ - EAST',
  'Employee ID Prefix': 'ဝန်ထမ်း ID ရှေ့ဆက်စာလုံး',
  'Example: E': 'ဥပမာ - E',
  'Full name': 'အမည်အပြည့်အစုံ',
  'Create a password': 'စကားဝှက် ဖန်တီးပါ',
  'Confirm Password': 'စကားဝှက် အတည်ပြုရန်',
  'Enter the password again': 'စကားဝှက်ကို ထပ်မံထည့်ပါ',
  'Create Business & Owner': 'လုပ်ငန်းနှင့် Owner ဖန်တီးရန်',
  'Backend unavailable': 'Backend အသုံးမပြုနိုင်ပါ',
  'Return to login': 'Login သို့ ပြန်ရန်',
  'Google Business Location': 'Google လုပ်ငန်းတည်နေရာ',
  'Search and select the exact Google Maps listing':
      'မှန်ကန်သော Google Maps စာရင်းကို ရှာပြီး ရွေးပါ',
  'Select Business Location': 'လုပ်ငန်းတည်နေရာ ရွေးပါ',
  'Search business name or address': 'လုပ်ငန်းအမည် သို့မဟုတ် လိပ်စာ ရှာပါ',
  'Searching Google Maps…': 'Google Maps တွင် ရှာဖွေနေသည်…',
  'Type at least 2 characters.': 'အနည်းဆုံး စာလုံး ၂ လုံး ရိုက်ထည့်ပါ။',
  'No matching location found.': 'ကိုက်ညီသော တည်နေရာ မတွေ့ပါ။',
  'Google Business Location is required. Replace HARDCODED_API_KEY in GooglePlacesProperties.java, restart the backend, then search again.':
      'Google လုပ်ငန်းတည်နေရာ လိုအပ်သည်။ GooglePlacesProperties.java ရှိ HARDCODED_API_KEY ကို အစားထိုးပြီး Backend ကို ပြန်ဖွင့်ကာ ထပ်မံရှာပါ။',
  'Country Code': 'နိုင်ငံကုဒ်',
  'Search country or code': 'နိုင်ငံ သို့မဟုတ် ကုဒ် ရှာပါ',
  'Phone number': 'ဖုန်းနံပါတ်',
  'Malaysia': 'မလေးရှား',
  'Singapore': 'စင်ကာပူ',
  'Indonesia': 'အင်ဒိုနီးရှား',
  'Thailand': 'ထိုင်း',
  'Philippines': 'ဖိလစ်ပိုင်',
  'Vietnam': 'ဗီယက်နမ်',
  'Brunei': 'ဘရူနိုင်း',
  'China': 'တရုတ်',
  'Hong Kong': 'ဟောင်ကောင်',
  'Taiwan': 'ထိုင်ဝမ်',
  'Japan': 'ဂျပန်',
  'South Korea': 'တောင်ကိုရီးယား',
  'India': 'အိန္ဒိယ',
  'Australia': 'ဩစတြေးလျ',
  'United Kingdom': 'ယူနိုက်တက်ကင်းဒမ်း',
  'United States / Canada': 'အမေရိကန် / ကနေဒါ',
  'Edit this business, create a business or switch context':
      'ဤလုပ်ငန်းကို ပြင်ဆင်ရန်၊ လုပ်ငန်းအသစ် ဖန်တီးရန် သို့မဟုတ် လုပ်ငန်းပြောင်းရန်',
  'View and edit this business': 'ဤလုပ်ငန်းကို ကြည့်ရှုပြင်ဆင်ရန်',
  'Create': 'ဖန်တီးရန်',
  'Search other businesses': 'အခြားလုပ်ငန်းများ ရှာရန်',
  'Other Businesses': 'အခြားလုပ်ငန်းများ',
  'No other business context is assigned.': 'အခြားလုပ်ငန်း အသုံးပြုခွင့် မသတ်မှတ်ထားပါ။',
  'Prefix': 'ရှေ့ဆက်စာလုံး',
  'Business Name required': 'လုပ်ငန်းအမည် လိုအပ်သည်',
  'Company Code required': 'ကုမ္ပဏီကုဒ် လိုအပ်သည်',
  'Use 2–32 letters, numbers, _ or -': 'စာလုံး၊ ဂဏန်း၊ _ သို့မဟုတ် - ၂ မှ ၃၂ လုံး အသုံးပြုပါ',
  'Employee ID Prefix required': 'ဝန်ထမ်း ID ရှေ့ဆက်စာလုံး လိုအပ်သည်',
  'Use 1–3 letters': 'စာလုံး ၁ မှ ၃ လုံး အသုံးပြုပါ',
  'Google business location required': 'Google လုပ်ငန်းတည်နေရာ လိုအပ်သည်',
  'Update Business?': 'လုပ်ငန်းကို ပြင်ဆင်မည်လား။',
  'Create Business?': 'လုပ်ငန်း ဖန်တီးမည်လား။',
  'This updates only this business.': 'ဤလုပ်ငန်းကိုသာ ပြင်ဆင်မည်။',
  'This creates a new isolated business, default roles and a separate Owner employee ID for every existing Owner.':
      'သီးခြားလုပ်ငန်းအသစ်၊ မူလရာထူးများနှင့် ရှိပြီးသား Owner တစ်ဦးစီအတွက် သီးခြား Owner ဝန်ထမ်း ID ကို ဖန်တီးမည်။',
  'Edit Business': 'လုပ်ငန်း ပြင်ဆင်ရန်',
  'Create Business': 'လုပ်ငန်း ဖန်တီးရန်',
  'Example: June Coffee': 'ဥပမာ - June Coffee',
  'Example: JUNE': 'ဥပမာ - JUNE',
  'Example: J': 'ဥပမာ - J',
  'Company Code and Employee ID Prefix cannot change after creation.':
      'ဖန်တီးပြီးနောက် Company Code နှင့် ဝန်ထမ်း ID ရှေ့ဆက်စာလုံးကို ပြောင်း၍မရပါ။',
  'Create Supplier?': 'ပေးသွင်းသူ ဖန်တီးမည်လား။',
  'This will create a new supplier for the this business.':
      'ဤလုပ်ငန်းအတွက် ပေးသွင်းသူအသစ် ဖန်တီးမည်။',
  'Submit Daily Stock Count?': 'နေ့စဉ်ကုန်လက်ကျန်ရေတွက်မှု တင်ပြမည်လား။',
  'This will create stock-count records and update the selected SKU balances.':
      'ကုန်လက်ကျန်ရေတွက်မှုမှတ်တမ်းများ ဖန်တီးပြီး ရွေးထားသော SKU လက်ကျန်များကို ပြင်ဆင်မည်။',
  'Submit Receiving?': 'ကုန်လက်ခံမှု တင်ပြမည်လား။',
  'This will create the receiving record and update the received SKU balances.':
      'ကုန်လက်ခံမှတ်တမ်းကို ဖန်တီးပြီး လက်ခံရရှိသော SKU လက်ကျန်များကို ပြင်ဆင်မည်။',
  'Update SKU?': 'SKU ကို ပြင်ဆင်မည်လား။',
  'This will save the edited SKU details and stock settings.':
      'ပြင်ဆင်ထားသော SKU အသေးစိတ်နှင့် ကုန်လက်ကျန်ဆက်တင်များကို သိမ်းမည်။',
  'Update SKU Assignees?': 'SKU တာဝန်ခံများကို ပြင်ဆင်မည်လား။',
  'This will replace the assignee list for the selected SKU.':
      'ရွေးထားသော SKU ၏ တာဝန်ခံစာရင်းကို အစားထိုးမည်။',
  'Delete Selected Suppliers?': 'ရွေးထားသော ပေးသွင်းသူများကို ဖျက်မည်လား။',
  'This will permanently delete the selected unassigned suppliers.':
      'ရွေးထားပြီး တာဝန်မချိတ်ထားသော ပေးသွင်းသူများကို အပြီးတိုင် ဖျက်မည်။',
  'Update Supplier?': 'ပေးသွင်းသူကို ပြင်ဆင်မည်လား။',
  'This will save the edited supplier information.':
      'ပြင်ဆင်ထားသော ပေးသွင်းသူအချက်အလက်ကို သိမ်းမည်။',
  'Delete Supplier?': 'ပေးသွင်းသူကို ဖျက်မည်လား။',
  'This will permanently delete this unassigned supplier.':
      'တာဝန်မချိတ်ထားသော ဤပေးသွင်းသူကို အပြီးတိုင် ဖျက်မည်။',
  'Create Tag?': 'Tag ဖန်တီးမည်လား။',
  'This will create a new Stock tag for the this business.':
      'ဤလုပ်ငန်းအတွက် ကုန်လက်ကျန် Tag အသစ် ဖန်တီးမည်။',
  'Delete Selected Tags?': 'ရွေးထားသော Tag များကို ဖျက်မည်လား။',
  'This will permanently delete the selected unassigned tags.':
      'ရွေးထားပြီး တာဝန်မချိတ်ထားသော Tag များကို အပြီးတိုင် ဖျက်မည်။',
  'Update Tag?': 'Tag ကို ပြင်ဆင်မည်လား။',
  'This will rename the selected tag.': 'ရွေးထားသော Tag အမည်ကို ပြောင်းမည်။',
  'Delete Tag?': 'Tag ကို ဖျက်မည်လား။',
  'This will permanently delete this unassigned tag.':
      'တာဝန်မချိတ်ထားသော ဤ Tag ကို အပြီးတိုင် ဖျက်မည်။',
  'Create SKU?': 'SKU ဖန်တီးမည်လား။',
  'This will upload the thumbnail and create a new SKU for the this business.':
      'Thumbnail ပုံကို တင်ပြီး ဤလုပ်ငန်းအတွက် SKU အသစ် ဖန်တီးမည်။',
  'Submit Task?': 'တာဝန်ကို တင်ပြမည်လား။',
  'This will submit the task and photo evidence for manager review.':
      'တာဝန်နှင့် ဓာတ်ပုံအထောက်အထားကို မန်နေဂျာစစ်ဆေးရန် တင်ပြမည်။',
  'Reject Task?': 'တာဝန်ကို ပယ်ချမည်လား။',
  'This will reject the submitted task and save the review result.':
      'တင်ပြထားသော တာဝန်ကို ပယ်ချပြီး စစ်ဆေးမှုရလဒ်ကို သိမ်းမည်။',
  'Approve Task?': 'တာဝန်ကို အတည်ပြုမည်လား။',
  'This will approve the submitted task and award the selected score.':
      'တင်ပြထားသော တာဝန်ကို အတည်ပြုပြီး ရွေးထားသော အမှတ်ကို ချီးမြှင့်မည်။',
  'Confirm without provider call': 'ဝန်ဆောင်မှုပေးသူကို မခေါ်ဘဲ အတည်ပြုရန်',
  'Load Report': 'အစီရင်ခံစာ ရယူရန်',
  'Reload Report': 'အစီရင်ခံစာ ပြန်လည်ရယူရန်',
  'Resolve Complaint': 'တိုင်ကြားချက် ဖြေရှင်းရန်',
  'Update Resolution': 'ဖြေရှင်းမှု ပြင်ဆင်ရန်',
  'Price Range': 'ဈေးနှုန်းအပိုင်းအခြား',
  'Previous Balance': 'ယခင်လက်ကျန်',
  'Below Min': 'အနည်းဆုံးအောက်',
  'Checked Values': 'စစ်ဆေးထားသော တန်ဖိုးများ',
  'Remarks': 'မှတ်ချက်များ',
  'Task Title': 'တာဝန်ခေါင်းစဉ်',
  'Checks': 'စစ်ဆေးချက်များ',
  'Stock Task': 'ကုန်လက်ကျန်တာဝန်',
  'Goods Photo': 'ကုန်ပစ္စည်းဓာတ်ပုံ',
  'Processing. Please wait.': 'လုပ်ဆောင်နေသည်။ ခဏစောင့်ပါ။',
  'All Roles': 'ရာထူးအားလုံး',
  'Unknown Tag': 'မသိသော Tag',
  'Temporary disabled': 'ယာယီ ပိတ်ထားသည်',
  'Complete supplier, SKU & qty': 'ပေးသွင်းသူ၊ SKU နှင့် အရေအတွက်ကို ပြည့်စုံစွာ ဖြည့်ပါ',
  'Add invoice & goods photos': 'ပြေစာနှင့် ကုန်ပစ္စည်းဓာတ်ပုံများ ထည့်ပါ',
  'Enter valid stock numbers': 'မှန်ကန်သော ကုန်လက်ကျန်ကိန်းဂဏန်းများ ထည့်ပါ',
  'Enter valid stock number': 'မှန်ကန်သော ကုန်လက်ကျန်ကိန်းဂဏန်း ထည့်ပါ',
  'Complete every SKU': 'SKU တိုင်းကို ပြည့်စုံစွာ ဖြည့်ပါ',
  'Updated': 'ပြင်ဆင်ပြီး',
  'Created': 'ဖန်တီးပြီး',
  'approved': 'အတည်ပြုပြီး',
  'completed': 'ပြီးစီးပြီး',
  'in_progress': 'လုပ်ဆောင်နေ',
  'items': 'ပစ္စည်း',
  'pending': 'စောင့်ဆိုင်း',
  'points': 'ပွိုင့်',
  'points earned': 'ပွိုင့် ရရှိပြီး',
  'rejected': 'ပယ်ချပြီး',
  'submitted': 'တင်ပြပြီး',
  'user': 'အသုံးပြုသူ',
  'Knowledge Audit': 'အသိပညာ စစ်ဆေးမှု',
  'Measure recorded SOP playback time':
      'မှတ်တမ်းတင်ထားသော SOP ဗီဒီယိုကြည့်ချိန်ကို တိုင်းတာရန်',
  'Playback effort': 'ဗီဒီယိုကြည့်ရှုအားထုတ်မှု',
  'By Employee': 'ဝန်ထမ်းအလိုက်',
  'Video Analytics': 'ဗီဒီယို ခွဲခြမ်းစိတ်ဖြာမှု',
  'Employee learning effort': 'ဝန်ထမ်း လေ့လာသင်ယူမှုအားထုတ်မှု',
  'Search, then tap an employee to load':
      'ဝန်ထမ်းကို ရှာပြီး အချက်အလက်ရယူရန် နှိပ်ပါ',
  'Name, employee ID, role or phone':
      'အမည်၊ ဝန်ထမ်း ID၊ ရာထူး သို့မဟုတ် ဖုန်း',
  'Search Employee': 'ဝန်ထမ်း ရှာရန်',
  'Unable to load employees. Try again.':
      'ဝန်ထမ်းများကို မရယူနိုင်ပါ။ ထပ်ကြိုးစားပါ။',
  'Unable to load employee learning time.':
      'ဝန်ထမ်း၏ လေ့လာချိန်ကို မရယူနိုင်ပါ။',
  'Unable to load video analytics. Try again.':
      'ဗီဒီယို ခွဲခြမ်းစိတ်ဖြာမှုကို မရယူနိုင်ပါ။ ထပ်ကြိုးစားပါ။',
  'No employee found.': 'ဝန်ထမ်း မတွေ့ပါ။',
  'Total active playback time': 'အမှန်တကယ်ဖွင့်ထားသော ဗီဒီယိုကြည့်ချိန် စုစုပေါင်း',
  'SOP videos watched': 'ကြည့်ရှုထားသော SOP ဗီဒီယိုများ',
  'No recorded active playback time yet.':
      'မှတ်တမ်းတင်ထားသော အမှန်တကယ်ဖွင့်ကြည့်ချိန် မရှိသေးပါ။',
  'Last watched': 'နောက်ဆုံးကြည့်ချိန်',
  'Compare SOP videos by total active playback time':
      'အမှန်တကယ်ဖွင့်ကြည့်ချိန် စုစုပေါင်းအလိုက် SOP ဗီဒီယိုများကို နှိုင်းယှဉ်ရန်',
  'Load Video Analytics': 'ဗီဒီယို ခွဲခြမ်းစိတ်ဖြာမှု ရယူရန်',
  'Refresh Video Analytics': 'ဗီဒီယို ခွဲခြမ်းစိတ်ဖြာမှု ပြန်ရယူရန်',
  'Data loads only when u press this button.':
      'ဤခလုတ်ကို နှိပ်မှသာ အချက်အလက်ရယူမည်။',
  'All active playback': 'အမှန်တကယ်ဖွင့်ကြည့်ချိန်အားလုံး',
  'Unique employees': 'မတူညီသော ဝန်ထမ်းများ',
  'Most watched SOP videos': 'အများဆုံးကြည့်သော SOP ဗီဒီယိုများ',
  'employees': 'ဝန်ထမ်း',
  'No SOP videos available.': 'SOP ဗီဒီယို မရှိပါ။',
  'Playback time is recorded only while the SOP video is actively playing in the foreground. It cannot prove attention or understanding.':
      'SOP ဗီဒီယိုကို မျက်နှာပြင်ပေါ်တွင် အမှန်တကယ်ဖွင့်ထားချိန်ကိုသာ မှတ်တမ်းတင်သည်။ အာရုံစိုက်မှု သို့မဟုတ် နားလည်မှုကို သက်သေမပြနိုင်ပါ။',
};

const Map<String, String> _chinese = {
  '\$label required': '\$label为必填项',
  'Access SOPs, recipes, and ingredients': '查看SOP、食谱和食材',
  'Active': '启用',
  'Advertisement': '广告',
  'Actor': '操作人',
  'Actors': '操作人',
  'Actual received': '实际收货',
  'Add SKU': '添加SKU',
  'Add Supplier': '添加供应商',
  'Add Tag': '添加标签',
  'Add any additional notes...': '添加其他备注……',
  'Address': '地址',
  'All': '全部',
  'All Time': '全部时间',
  'All supplier messages copied': '已复制所有供应商消息',
  'Apply': '应用',
  'Approvals': '审批',
  'Approve': '批准',
  'Approve All': '全部批准',
  'Approved': '已批准',
  'Assign': '分配',
  'Assign SKU to user': '将SKU分配给用户',
  'Assign SKU to user.': '将SKU分配给用户。',
  'Assigned': '已分配',
  'Assigned tags cannot be deleted': '已使用的标签无法删除',
  'Assignee': '负责人',
  'Assignee updated': '负责人已更新',
  'Attendance': '考勤',
  'Attendance reports': '考勤报告',
  'Audit': '审计',
  'Audit Inbound': '入库审计',
  'Audit Trail': '审计记录',
  'Average': '平均',
  'Back': '返回',
  'Backlog': '待处理',
  'Balance': '库存量',
  'Balance must be Min / Max.': '库存量必须在最小值与最大值之间。',
  'Business': '业务',
  'Camera only': '仅限相机',
  'Camera photo captured': '已拍摄照片',
  'Cancel': '取消',
  'Capture photos, then SKU.': '先拍照，再选择SKU。',
  'Captured': '已拍摄',
  'Career Path': '职业发展',
  'Career mentor': '职业导师',
  'Climb from Staff to Head': '从员工逐步晋升至负责人',
  'Current role': '当前职位',
  'Your climb': '你的晋升路线',
  'Tap any role': '点击任意职位',
  'Staff 1': '员工 1',
  'Staff 2': '员工 2',
  'Supervisor': '主管',
  'Manager': '经理',
  'Head': '负责人',
  'Build the foundation': '打好基础',
  'Own the routine': '独立掌握日常工作',
  'Guide the shift': '带领班次',
  'Lead operations': '领导运营',
  'Reach the summit': '登上顶峰',
  'Learn the essentials and build reliable daily habits.':
      '学习核心工作，建立可靠的日常习惯。',
  'Handle daily work confidently, consistently and independently.':
      '自信、稳定且独立地完成日常工作。',
  'Support the team, spot issues early and keep the shift moving.':
      '支持团队，及早发现问题，确保班次顺利运作。',
  'Make decisions, develop people and own operational results.':
      '做出决策、培养员工，并对运营成果负责。',
  'Set direction, grow leaders and shape how the business succeeds.':
      '制定方向、培养领导者，并塑造业务成功方式。',
  'Next climb': '下一阶',
  'Unlocked': '已解锁',
  'Summit': '顶峰',
  'Ahead': '待晋升',
  'Notifications': '通知',
  'Business changes from other people': '其他人员的业务变更',
  'No notifications yet.': '暂无通知。',
  'No recent activity yet.': '暂无最近动态。',
  'Remove': '移除',
  'Activity Details': '动态详情',
  'Who': '人员',
  'Area': '模块',
  'What happened': '操作内容',
  'When': '时间',
  'Record ID': '记录ID',
  'Change log': '变更记录',
  'Changed Value': '变更值',
  'Checklist': '检查清单',
  'Checklist \${index + 1}': '检查项 \${index + 1}',
  'Checklist checked': '检查清单已确认',
  'Clear': '清除',
  'Clear All': '全部清除',
  'Click to upload photo': '点击上传照片',
  'Clock in/out': '上下班打卡',
  'Company ID': '公司ID',
  'Complete all fields.': '请填写所有字段。',
  'Complete tasks to earn points': '完成任务以获得积分',
  'Completed': '已完成',
  'Confirm': '确认',
  'Confirm Approve All': '确认全部批准',
  'Confirm Reject All': '确认全部拒绝',
  'Confirm Submit All': '确认全部提交',
  'Contact': '联系人',
  'Contact Person': '联系人',
  'Contacts': '通讯录',
  'Choose from contacts': '从通讯录选择',
  'Search contacts': '搜索联系人',
  'No contacts with phone numbers': '没有带电话号码的联系人',
  'Full Contacts access is required. Allow it in Settings.':
      '需要完整的通讯录权限。请在“设置”中允许。',
  "This contact's country code is not supported.": '不支持此联系人的国家区号。',
  'Could not load contacts.': '无法载入通讯录。',
  'Copy Message': '复制消息',
  'Count': '盘点',
  'Count stock / receive goods / prepare restock': '盘点库存／收货／准备补货',
  'Counted By': '盘点人',
  'Create New SOP': '新建SOP',
  'Create Role': '创建角色',
  'Create SOP': '创建SOP',
  'Create Supplier': '创建供应商',
  'Create User': '创建用户',
  'Create a Tag in Stock first.': '请先在库存中创建标签。',
  'Create supplier first': '请先创建供应商',
  'Create suppliers': '创建供应商',
  'Create tag first': '请先创建标签',
  'Create/list SKU': '创建／查看SKU',
  'Create/list Supplier': '创建／查看供应商',
  'Created By': '创建人',
  'Created Date': '创建日期',
  'Current': '当前',
  'Current Balance': '当前库存量',
  'Current Stock': '当前库存',
  'Custom Category': '自定义分类',
  'Daily Count Backlog': '每日盘点待处理',
  'Daily Count Records': '每日盘点记录',
  'Daily Count Review': '每日盘点审核',
  'Daily count approved': '每日盘点已批准',
  'Daily count records approved': '每日盘点记录已批准',
  'Daily count records rejected': '每日盘点记录已拒绝',
  'Daily count rejected': '每日盘点已拒绝',
  'Daily stock count submitted': '每日库存盘点已提交',
  'Delete': '删除',
  'Deleted': '已删除',
  'Description': '说明',
  'Description:': '说明：',
  'Edit': '编辑',
  'Edit SOP': '编辑SOP',
  'Employee ID': '员工ID',
  'Enter a valid phone number.': '请输入有效的电话号码。',
  'Enter your password': '请输入密码',
  'Entries': '记录数',
  'Example: 0123456789': '例如：0123456789',
  'Example: 1kg damaged / item missing': '例如：损坏1公斤／物品缺失',
  'Example: Chicken': '例如：鸡肉',
  'Example: Chiller': '例如：冷藏',
  'Example: Fresh Farm Supplier': '例如：Fresh Farm供应商',
  'Example: GTI Kampar': '例如：GTI Kampar',
  'Example: Mr Tan': '例如：陈先生',
  'Expected Outcome:': '预期结果：',
  'Filter by assignee': '按负责人筛选',
  'Gallery upload disabled': '已禁用相册上传',
  'Good': '正常',
  'Goods Received': '已收货',
  'Goods Received Photo': '收货照片',
  'Home': '主页',
  'Home Dashboard': '主页概览',
  'In Use': '使用中',
  'Invoice': '发票',
  'Invoice & goods check': '发票与货物检查',
  'Invoice Photo': '发票照片',
  'Invoice Qty': '发票数量',
  'Knowledge': '知识',
  'Knowledge Pool': '知识库',
  'Language': '语言',
  'English': '英语',
  'Myanmar': '缅甸语',
  'Linked Video': '关联视频',
  'No linked video': '不关联视频',
  'Select Language': '选择语言',
  'Select Video Language': '选择视频语言',
  'Select a previously created video': '选择之前创建的视频',
  'SOP Details': 'SOP详情',
  'Video Version': '视频版本',
  'Video Versions': '视频版本',
  'Language is fixed while two video versions are linked.':
      '关联两个视频版本后，不能更改语言。',
  'Maximum two linked videos. Linked versions are deleted together.':
      '最多关联两个视频，关联版本会一起删除。',
  'Last Updated': '最后更新',
  'Leaderboard': '排行榜',
  'List users': '用户列表',
  'Load Audit': '加载审计记录',
  'Load More': '加载更多',
  'Loaded': '已加载',
  'Loading...': '加载中……',
  'Low': '不足',
  'Low Stock Only': '仅显示低库存',
  'Manage SOP': '管理SOP',
  'Manage businesses': '管理业务',
  'Manage roles': '管理角色',
  'Manage roles and availability.': '管理角色及启用状态。',
  'Manage users, roles and attendance': '管理用户、角色和考勤',
  'Manager Score': '经理评分',
  'Max': '最大',
  'Max Balance': '最大库存量',
  'Max Price': '最高价格',
  'Maximum': '最大值',
  'Maximum 30 days.': '最多30天。',
  'Media selected': '已选择媒体',
  'Message': '消息',
  'Message copied to clipboard': '消息已复制到剪贴板',
  'Min': '最小',
  'Min Balance': '最小库存量',
  'Min Price': '最低价格',
  'Minimum': '最小值',
  'Module': '模块',
  'Nic\'s Kitchen': 'Nic\'s Kitchen',
  'No SKU found': '找不到SKU',
  'No SKU found.': '找不到SKU。',
  'No SKU matches the selected filters.': '没有符合所选筛选条件的SKU。',
  'No SOP found.': '找不到SOP。',
  'No audit trail found.': '找不到审计记录。',
  'No backlog records found.': '找不到待处理记录。',
  'No daily count found.': '找不到每日盘点记录。',
  'No low-stock SKU today.': '今天没有低库存SKU。',
  'No receiving records found.': '找不到收货记录。',
  'No remark provided.': '未提供备注。',
  'No supplier found': '找不到供应商',
  'No tag found': '找不到标签',
  'No user available.': '没有可用用户。',
  'Non editable. Manager or Head updates inside Stock Check.': '不可编辑。由经理或Head在库存检查中更新。',
  'None': '无',
  'Notes': '备注',
  'Open Camera': '打开相机',
  'Operation': '操作',
  'Optional camera proof': '可选相机凭证',
  'Overdue, rejected and approved records.': '逾期、已拒绝及已批准的记录。',
  'Password': '密码',
  'Pending': '待处理',
  'Pending Review': '待审核',
  'Pending Reviews': '待审核',
  'People': '人员',
  'People Dashboard': '人员概览',
  'Phone': '电话',
  'Phone Number': '电话号码',
  'Photo Evidence': '照片凭证',
  'Photo required': '必须提供照片',
  'Photo selected': '已选择照片',
  'Picture': '图片',
  'Please confirm these daily count records before applying bulk action.': '批量操作前，请确认这些每日盘点记录。',
  'Please confirm these receiving records before applying bulk action.': '批量操作前，请确认这些收货记录。',
  'Please confirm these receiving records before submitting.': '提交前，请确认这些收货记录。',
  'Please enter valid numbers.': '请输入有效数字。',
  'Points Earned': '已获得积分',
  'Previous Value': '原值',
  'Price': '价格',
  'Price must be Min / Max.': '价格必须在最低价与最高价之间。',
  'Purchase': '采购',
  'Qty on invoice': '发票数量',
  'Ready': '就绪',
  'Received At': '收货时间',
  'Received By': '收货人',
  'Received Qty': '收货数量',
  'Receiving': '收货',
  'Receiving Backlog': '收货待处理',
  'Receiving Checklist': '收货检查清单',
  'Receiving Records': '收货记录',
  'Receiving Review': '收货审核',
  'Receiving record approved': '收货记录已批准',
  'Receiving record rejected': '收货记录已拒绝',
  'Receiving records approved': '收货记录已批准',
  'Receiving records rejected': '收货记录已拒绝',
  'Report': '报告',
  'Daily Photos': '每日照片',
  'Photos Taken': '已拍照片',
  'Receiving submitted': '收货记录已提交',
  'Recent Activity': '最近活动',
  'Recovery': '恢复',
  'Reject': '拒绝',
  'Reject All': '全部拒绝',
  'Reject reason, optional': '拒绝原因（可选）',
  'Rejected': '已拒绝',
  'Reload Audit': '重新加载审计记录',
  'Remark': '备注',
  'Remarks (Optional)': '备注（可选）',
  'Required': '必填',
  'Reset': '重置',
  'Reset Time': '重置时间',
  'Reset Time required': '必须填写重置时间',
  'Restock': '补货',
  'Retake Photo': '重新拍照',
  'Review': '审核',
  'Review Note': '审核备注',
  'Review Status': '审核状态',
  'Review Submission': '审核提交内容',
  'Review daily counts and receiving records.': '审核每日盘点及收货记录。',
  'Review staff submissions and rate out of 10': '审核员工提交内容并以10分制评分',
  'Review the message, then copy and paste it to supplier chat.': '检查消息后，复制并粘贴到供应商聊天。',
  'Reviewed At': '审核时间',
  'Reviewed By': '审核人',
  'Role': '角色',
  'SKU': 'SKU',
  'SKU Name': 'SKU名称',
  'SKU Photo': 'SKU照片',
  'SKU created': 'SKU已创建',
  'SOP created. Staff can view it now.': 'SOP已创建，员工现在可以查看。',
  'SOP deleted.': 'SOP已删除。',
  'SOPs deleted.': 'SOP已删除。',
  'SOP updated.': 'SOP已更新。',
  'Save': '保存',
  'Save SKU': '保存SKU',
  'Save Supplier': '保存供应商',
  'Saved': '已保存',
  'Saving...': '保存中……',
  'Schedule': '排班',
  'Search': '搜索',
  'Search SKU or user': '搜索SKU或用户',
  'Search SOP...': '搜索SOP……',
  'Search and edit users.': '搜索并编辑用户。',
  'Search audit trail': '搜索审计记录',
  'Search backlog': '搜索待处理记录',
  'Search daily count': '搜索每日盘点',
  'Search receiving': '搜索收货记录',
  'Search roles': '搜索角色',
  'Search supplier': '搜索供应商',
  'Search tag': '搜索标签',
  'Search users': '搜索用户',
  'Search, filter and edit SKU.': '搜索、筛选并编辑SKU。',
  'Select': '选择',
  'Select Date Range': '选择日期范围',
  'Select SKU': '选择SKU',
  'Select SKU first.': '请先选择SKU。',
  'Select SOP': '选择SOP',
  'Select All': '全选',
  'selected': '项已选择',
  'Select Tag': '选择标签',
  'Select Video / Picture': '选择视频／图片',
  'Select a date range, then load the audit trail.': '请选择日期范围，然后加载审计记录。',
  'Select at least one record': '请至少选择一条记录',
  'Setup - Owner & Head': '设置－Owner与Head',
  'Shift planning': '排班规划',
  'Showing': '显示中',
  'Sign In': '登录',
  'Staff Remark': '员工备注',
  'Standard Operating Procedure': '标准作业程序',
  'State changes only. Select up to 30 days.': '仅显示状态变更。最多选择30天。',
  'Status': '状态',
  'Stock': '库存',
  'Stock Balance': '库存量',
  'Stock Dashboard': '库存概览',
  'Stock Level': '库存水平',
  'Stock Thumbnail': '库存缩略图',
  'Stock Thumbnail required': '必须提供库存缩略图',
  'Submissions Reviewed': '已审核提交',
  'Submit All': '全部提交',
  'Submit Daily Count': '提交每日盘点',
  'Submit Task': '提交任务',
  'Submit for Approval': '提交审批',
  'Submitted': '已提交',
  'Submitted just now': '刚刚提交',
  'Submitted recently': '最近提交',
  'Supplier': '供应商',
  'Supplier Name': '供应商名称',
  'Supplier Purchase Setup': '供应商采购设置',
  'Supplier created': '供应商已创建',
  'Supplier purchase setup is managed by Head': '供应商采购设置由Head管理',
  'Supplier required': '必须选择供应商',
  'Supplier restock message copied': '供应商补货消息已复制',
  'Suppliers': '供应商',
  'Suppliers link inside SKU Setup.': '供应商关联在SKU设置中管理。',
  'Tag': '标签',
  'Tag 1': '标签1',
  'Tag 1 required': '必须选择标签1',
  'Tag 2': '标签2',
  'Tag 2 required': '必须选择标签2',
  'Tag already exists': '标签已存在',
  'Tag is required': '必须选择标签',
  'Take Photo': '拍照',
  'Take a fresh photo of the supplier invoice.': '请重新拍摄供应商发票。',
  'Take one photo showing the goods received for this supplier.': '请拍摄一张显示该供应商收货情况的照片。',
  'Tap photo to view. Tap balance to update.': '点击照片查看；点击库存量更新。',
  'Tap supplier to preview message.': '点击供应商预览消息。',
  'Task Approvals': '任务审批',
  'Task approved': '任务已批准',
  'Task rejected': '任务已拒绝',
  'Task submitted for manager approval': '任务已提交经理审批',
  'Task': '任务',
  'Tasks': '任务',
  'Tasks Completed': '已完成任务',
  'Tasks done': '已完成任务',
  'This Month': '本月',
  'This Week': '本周',
  'Timer': '计时器',
  'Title': '标题',
  'Today': '今天',
  'Today\'s Progress': '今日进度',
  'Today\'s Reviews': '今日审核',
  'Total': '总计',
  'Total Points': '总积分',
  'Total SKU': 'SKU总数',
  'Transparent point ranking': '透明积分排名',
  'Unassigned': '未分配',
  'Unassigned Supplier': '未分配供应商',
  'Unit': '单位',
  'Up 3 ranks': '上升3名',
  'Update daily physical stock balance': '更新每日实际库存量',
  'Upload Photo Evidence *': '上传照片凭证 *',
  'Upload Video / Picture': '上传视频／图片',
  'User': '用户',
  'Valid number required': '必须输入有效数字',
  'Video': '视频',
  'Video tutorial available': '提供视频教程',
  'View SOP': '查看SOP',
  'View Tasks': '查看任务',
  'View attendance': '查看考勤',
  'View roles': '查看角色',
  'View roles.': '查看角色。',
  'View users.': '查看用户。',
  'Watch Video': '观看视频',
  'Your Current Rank': '当前排名',
  'Settings': '设置',
  'Localisation': '界面语言',
  'Translate': '翻译内容',
  'Chinese': '中文',
  'Close': '关闭',
  'Original content (off)': '原始内容（关闭翻译）',
  'Choose the language for fixed app labels.': '选择固定界面标签所使用的语言。',
  'Translate user-entered content. The original and both translations are stored for reuse.':
      '翻译用户输入的内容。原文及另外两种译文会保存到数据库供重复使用。',
  'Save settings': '保存设置',
  'Saving settings...': '正在保存设置...',
  'Checking the translation cache...': '正在检查翻译缓存...',
  'Applying translation...': '正在应用翻译...',
  'Translation cost confirmation': '翻译费用确认',
  'The cache check is complete. Cloudflare has not been called.':
      '缓存检查已完成，尚未调用 Cloudflare。',
  'Content found this session': '本次登录期间找到的内容',
  'Stored translations': '已存储的翻译',
  'Selected-language cache misses': '所选语言缓存缺失',
  'Companion-language cache misses': '配套语言缓存缺失',
  'New Cloudflare requests': '新的 Cloudflare 请求',
  'Cloudflare is unavailable. Missing selected-language translations cannot be completed.':
      'Cloudflare 当前不可用，无法完成所选语言中缺失的翻译。',
  'Cloudflare is unavailable, but the selected language is fully cached and can be used without a provider call.':
      'Cloudflare 当前不可用，但所选语言已全部缓存，无需调用服务即可使用。',
  'Cloudflare Workers AI may create billable usage for these new requests. Use carefully.':
      '这些新请求可能产生 Cloudflare Workers AI 计费用量，请谨慎使用。',
  'Everything required is cached. Confirming will not call Cloudflare.':
      '所需翻译均已缓存，确认后不会调用 Cloudflare。',
  'Exact behaviour': '具体行为',
  'Changing a dropdown does nothing until Save.':
      '更改下拉选项不会立即执行，只有点击“保存”才会生效。',
  'Back or forward navigation never calls Cloudflare.':
      '前进或后退页面不会调用 Cloudflare。',
  'Save checks PostgreSQL first; cache hits do not call Cloudflare.':
      '保存时会先检查 PostgreSQL；命中缓存时不会调用 Cloudflare。',
  'Only missing translations call Cloudflare after confirmation.':
      '确认后，只有缺失的翻译才会调用 Cloudflare。',
  'One uncached source can create up to two Cloudflare requests because both other languages are stored.':
      '由于系统会保存另外两种语言，一个未缓存的原文最多会产生两次 Cloudflare 请求。',
  'Save includes matching content discovered on visited pages in the current sign-in session, not only the visible page.':
      '保存时会包含本次登录期间已访问页面中发现的匹配内容，而不只限于当前页面。',
  'Newly loaded content stays original until the next Save.':
      '新加载的内容会保持原文，直到下次点击“保存”。',
  'Double-clicking Save or Confirm does not send another request.':
      '重复点击“保存”或“确认”不会发送第二个请求。',
  'Localisation changes fixed labels only and never calls Cloudflare.':
      '本地化只更改固定界面标签，绝不会调用 Cloudflare。',
  'Saving Original content (off) never calls Cloudflare.':
      '保存“原始内容（关闭翻译）”绝不会调用 Cloudflare。',
  'Cloudflare may record billable usage even if a submitted provider request later fails.':
      '即使已提交的服务请求之后失败，Cloudflare 仍可能记录可计费用量。',
  'This estimate uses the current database cache. Another completed translation can only reduce the actual request count.':
      '此估算基于当前数据库缓存；若其他翻译先完成，实际请求数只会减少。',
  'Confirm & translate': '确认并翻译',
  'Use cache & save': '使用缓存并保存',
  'Action': '操作',
  'Add or deduct points': '增加或扣除积分',
  'Assign or deduct accumulated points': '分配或扣除累计积分',
  'Assignment status': '分配状态',
  'Current business · All time': '当前企业 · 全部时间',
  'Done': '完成',
  'Goods received photo captured': '收货照片已拍摄',
  'Invoice photo captured': '发票照片已拍摄',
  'Load': '加载',
  'Load Assigned or Unassigned SKU only when needed.':
      '仅在需要时加载已分配或未分配的 SKU。',
  'Load more': '加载更多',
  'Load more users': '加载更多用户',
  'No SKU matches the selected criteria.': '没有符合所选条件的 SKU。',
  'Nothing is loaded by default. Select Assigned or Unassigned, then press Load.':
      '默认不加载任何数据。选择“已分配”或“未分配”，然后点击“加载”。',
  'Points': '积分',
  'Processing... Please Wait!': '处理中... 请稍候！',
  'Results': '结果',
  'Retry': '重试',
  'Review submitted daily stock counts': '审核已提交的每日库存盘点',
  'Review submitted receiving records': '审核已提交的收货记录',
  'Search SKU (optional)': '搜索 SKU（可选）',
  'Select Status AND Date, then press Search.':
      '选择状态和日期，然后点击“搜索”。',
  'Submitted counts cannot be edited.': '已提交的盘点记录无法编辑。',
  'Take a clear photo of this SKU.': '请清晰拍摄此 SKU。',
  'View role hierarchy': '查看角色层级',
  'Cash Total': '现金总额',
  'eWallet Total': '电子钱包总额',
  'Gross Delivery': '外送平台销售总额',
  'Net Delivery (60%)': '外送净额（60%）',
  'Platform Commission': '平台佣金',
  'Total Sales': '总销售额',
  'Staff on Duty': '当值员工',
  'Sales / Staff-Day': '每员工日销售额',
  'Void Total': '作废单总额',
  'Void Exposure': '作废风险占比',
  'Net Delivery': '外送净额',
  'Stock Value': '库存价值',
  'Reorder Need': '补货需求',
  'Overstock Capital': '过量库存占用资金',
  'Out / Low': '缺货／低库存',
  'Copied SKU from another business': '从其他企业复制 SKU',
  'Created tag': '已创建标签',
  'Renamed tag': '已重命名标签',
  'Deleted tag': '已删除标签',
  'Created supplier': '已创建供应商',
  'Edited supplier': '已编辑供应商',
  'Deleted supplier': '已删除供应商',
  'Supplier Balance': '供应商余额',
  'Updated supplier balance': '已更新供应商余额',
  'Created SKU': '已创建 SKU',
  'Edited SKU': '已编辑 SKU',
  'SKU Balance': 'SKU 余额',
  'Updated balance': '已更新余额',
  'Stock Count': '库存盘点',
  'Submitted daily count': '已提交每日盘点',
  'Reviewed daily count': '已审核每日盘点',
  'Bulk reviewed daily count': '已批量审核每日盘点',
  'Submitted receiving': '已提交收货记录',
  'Reviewed receiving': '已审核收货记录',
  'Source Business': '来源企业',
  'Supplier Item': '供应商品项',
  'Name': '名称',
  'Photo': '照片',
  'Items': '项目',
  'Sales Reports': '销售报告',
  'Sales Report': '销售报告',
  'Void Bill Evidence': '作废账单凭证',
  'Inventory Intelligence': '库存智能分析',
  'Waste Intelligence': '损耗智能分析',
  'Complaints': '投诉',
  'Report Approvals': '报告审批',
  'Review & Decide': '审核并决定',
  'Report Intelligence': '报告智能分析',
  'Operational evidence transformed into business decisions':
      '将运营证据转化为业务决策',
  'Refresh report data': '刷新报告数据',
  'Avg Sales / Reporting Day': '每报告日平均销售额',
  'Count Coverage': '盘点覆盖率',
  'Total Labour Hours': '总工时',
  'Sales / Labour Hour': '每工时销售额',
  'Avg Staff / Day': '每日平均员工数',
  'Complete': '已完成',
  'Not loaded': '尚未加载',
  'Sales': '销售',
  'Waste': '损耗',
  'Evidence': '凭证',
  'Restricted': '受限制',
  'Submit': '提交',
  'Daily revenue, productivity and void-control intelligence':
      '每日营收、生产力及作废单控制分析',
  'Record every void bill with compulsory photo evidence':
      '每张作废单都必须附上照片凭证',
  'Void-control reporting': '作废单控制报告',
  'Create today’s Sales Report': '创建今天的销售报告',
  'Calculated stock health, capital exposure and reorder priorities':
      '计算库存健康度、资金占用风险及补货优先级',
  'Management-only calculated business intelligence':
      '仅限管理层查看的业务智能分析',
  'Inventory health score': '库存健康评分',
  'Management view': '管理视图',
  'Capture evidence and calculate the real cost of wastage':
      '记录凭证并计算损耗的实际成本',
  'Waste evidence': '损耗凭证',
  'Every staff submits at least 5 photos; manager approves the batch':
      '每位员工至少提交 5 张照片，由经理批量审批',
  'Staff completed today': '今日已完成人员',
  'Your photos today': '你今天的照片',
  'Track customer profile, action, compensation and resolution':
      '追踪客户资料、处理行动、赔偿及解决状态',
  'Open complaints': '未解决投诉',
  'Customer complaint': '客户投诉',
  'Sales vs Operational Leakage': '销售额与运营流失',
  'Void': '作废单',
  'Upcoming Feature': '即将推出的功能',
  'This feature is not available yet.': '此功能尚未开放。',
  'OK': '确定',
  'Total Sales Today': '今日总销售额',
  'Stock Health': '库存健康度',
  'Tasks to Rate': '待评分任务',
  'Submission': '提交状态',
  'Open Complaints': '未解决投诉',
  'SOP': 'SOP',
  'Expected Outcome': '预期结果',
  'YouTube URL': 'YouTube网址',
  'Enter a valid YouTube video URL.': '请输入有效的YouTube视频网址。',
  'English and Myanmar must use different YouTube videos.':
      '英文和缅甸文必须使用不同的YouTube视频。',
  'Update SOP?': '更新SOP？',
  'Create SOP?': '创建SOP？',
  'This will save the edited SOP information.': '这将保存已编辑的SOP信息。',
  'This will create a new SOP for the selected Stock tag.':
      '这将为所选库存标签创建新的SOP。',
  'Example: Belly Pork Preparation': '例如：五花肉处理',
  'Title is required.': '标题为必填项。',
  'What should staff achieve after following this?':
      '员工按照此流程操作后应达到什么结果？',
  'Expected Outcome is required.': '预期结果为必填项。',
  'Describe the SOP content': '说明SOP内容',
  'Description is required.': '说明为必填项。',
  'Search employee': '搜索员工',
  'Employee Status': '员工状态',
  'Searching...': '正在搜索...',
  'Search Employees': '搜索员工',
  'People Audit': '人员考勤审计',
  'Search an employee to view attendance history': '搜索员工以查看考勤记录',
  'Enter a name or employee ID, then tap Search Employees.':
      '输入姓名或员工编号，然后点击“搜索员工”。',
  'No employees found.': '未找到员工。',
  'Employees': '员工',
  'Load More Employees': '加载更多员工',
  'Attendance Period': '考勤周期',
  'Day': '日',
  'Week': '周',
  'Month': '月',
  'Year': '年',
  'Present days': '出勤天数',
  'Missing out': '缺少签退',
  'Completion': '完成率',
  'Total working': '总工时',
  'Average / day': '日均工时',
  'Attendance Table': '考勤表',
  'Confirmed working time includes completed Check In + Check Out records only.':
      '确认工时仅包括已完成签到和签退的记录。',
  'No attendance records in this period.': '此期间没有考勤记录。',
  'Attendance Events': '考勤事件',
  'No attendance events in this period.': '此期间没有考勤事件。',
  'Date': '日期',
  'Check In': '签到',
  'Check Out': '签退',
  'Working Time': '工作时长',
  'Annual Attendance Performance': '年度考勤表现',
  'Attendance reliability': '考勤完整率',
  'Missing Check Outs': '缺少签退',
  'Average working / completed day': '已完成日平均工时',
  'Average Clock In': '平均签到时间',
  'Monthly Breakdown': '月度明细',
  'Tap a month to open its detailed payroll attendance view.':
      '点击月份以查看详细的薪资考勤记录。',
  'Present': '出勤',
  'Missing Out': '缺少签退',
  'Hours': '工时',
  'Incomplete attendance': '考勤未完成',
  'Only Owner, Head and Manager can generate attendance QR codes.':
      '只有Owner、Head和Manager可以生成考勤二维码。',
  'Clock out completed': '签退完成',
  'Clock in completed': '签到完成',
  'Location Services is off. Turn on Location Services to use Attendance.':
      '定位服务已关闭。请开启定位服务以使用考勤。',
  'Location permission denied. Allow location access to use Attendance.':
      '定位权限被拒绝。请允许访问位置以使用考勤。',
  'Location permission permanently denied. Open app settings and allow location access.':
      '定位权限已被永久拒绝。请打开应用设置并允许访问位置。',
  'Location service is off. Turn on Location Services to continue Attendance.':
      '定位服务已关闭。请开启定位服务以继续考勤。',
  'Location permission is required to continue Attendance.':
      '继续考勤需要定位权限。',
  'Location permission is permanently denied. Open app settings and allow location access.':
      '定位权限已被永久拒绝。请打开应用设置并允许访问位置。',
  'Unable to capture the current GPS location. Please try again.':
      '无法获取当前GPS位置。请重试。',
  'Location access required': '需要定位权限',
  'GPS location is required for attendance and is recorded with each Check In / Out.':
      '考勤需要GPS位置，每次签到和签退都会记录位置。',
  'Location Settings': '定位设置',
  'App Settings': '应用设置',
  'Select an attendance action. Data is loaded only when requested.':
      '选择考勤操作。仅在请求时加载数据。',
  'Check In / Out': '签到／签退',
  'Load today\'s attendance, then scan the required QR code.':
      '加载今天的考勤，然后扫描所需二维码。',
  'QR Code': '二维码',
  'Generate a 30-minute Check In or Check Out QR code.':
      '生成有效期30分钟的签到或签退二维码。',
  'Owner, Head or Manager permission is required.':
      '需要Owner、Head或Manager权限。',
  'Completed for today': '今天已完成',
  'Checked in · ready to check out': '已签到 · 可以签退',
  'Not checked in': '尚未签到',
  'GPS location and a valid attendance QR are required.':
      '需要GPS位置和有效的考勤二维码。',
  'Already checked in today.': '今天已经签到。',
  'Scan a valid Check In QR code.': '扫描有效的签到二维码。',
  'Already checked out today.': '今天已经签退。',
  'Scan a valid Check Out QR code.': '扫描有效的签退二维码。',
  'Available after Check In.': '签到后可用。',
  'Attendance QR Code': '考勤二维码',
  'Select the action first, then press Generate QR. Each QR works for any employee in this business for 30 minutes.':
      '先选择操作，然后点击“生成二维码”。每个二维码可供本业务的任何员工使用30分钟。',
  'QR Action': '二维码操作',
  'Generating...': '正在生成...',
  'Generate QR': '生成二维码',
  'Generate New QR': '生成新二维码',
  'Expired': '已过期',
  'This QR has expired. Generate a new QR to continue.':
      '此二维码已过期。请生成新二维码以继续。',
  'Clock In': '签到',
  'Clock Out': '签退',
  'Approved.': '已批准。',
  'Rejected.': '已拒绝。',
  'Selected records approved': '所选记录已批准',
  'Selected records rejected': '所选记录已拒绝',
  'Approve Receiving Record?': '批准收货记录？',
  'Reject Receiving Record?': '拒绝收货记录？',
  'This will update the review status of this receiving record.':
      '这将更新此收货记录的审核状态。',
  'Approve Daily Count?': '批准每日盘点？',
  'Reject Daily Count?': '拒绝每日盘点？',
  'This will update the review status of this daily stock count.':
      '这将更新此每日库存盘点的审核状态。',
  'This will update all selected records.': '这将更新所有选中的记录。',
  'Search Again': '再次搜索',
  'No records are loaded by default. Select Status and Date, then press Search.':
      '默认不加载记录。请选择状态和日期，然后点击搜索。',
  'No daily count records found.': '未找到每日盘点记录。',
  'Details': '详情',
  'changed to': '更改为',
  'Fixed EastApp role hierarchy': '固定的EastApp角色层级',
  'No role found': '未找到角色',
  'Owner → Head → Manager → Supervisor → Staff1 → Staff2. Roles are fixed and cannot be created, renamed or deleted.':
      'Owner → Head → Manager → Supervisor → Staff1 → Staff2。角色固定，不能创建、重命名或删除。',
  'Refresh': '刷新',
  'No user found': '未找到用户',
  'Last': '最后工作日',
  'Coming soon. User setup is enabled first.': '即将推出。目前先启用用户设置。',
  'Deactivate User': '停用用户',
  'Deactivate User?': '停用用户？',
  'This will set the user to inactive using the selected last working date.':
      '这将根据所选最后工作日把用户设为停用。',
  'User set to inactive': '用户已设为停用',
  'Status will be set to Inactive and all sessions will be revoked.':
      '状态将设为停用，并撤销所有会话。',
  'Set User Inactive': '将用户设为停用',
  'Update User?': '更新用户？',
  'Create User?': '创建用户？',
  'This will assign Owner access and a separate employee ID in every business.':
      '这将在每个业务中分配Owner权限及独立的员工编号。',
  'This will update the selected user account and access settings.':
      '这将更新所选用户账户及访问设置。',
  'User updated': '用户已更新',
  'User created': '用户已创建',
  'Edit User': '编辑用户',
  'Employee ID will be generated automatically by this business.':
      '此业务将自动生成员工编号。',
  'New Password (Optional)': '新密码（可选）',
  'Minimum 4 characters': '至少4个字符',
  'Required for a new person; blank for an existing login':
      '新用户必填；已有登录账户则留空',
  'When the phone number already belongs to an application login, the same profile and password are reused and only a new employee ID is created for this business.':
      '如果电话号码已属于应用登录账户，将重复使用同一资料和密码，并仅为此业务创建新的员工编号。',
  'Full Name': '全名',
  'Example: Nicky Chang': '例如：Nicky Chang',
  'Born Date': '出生日期',
  'Loading roles for this business...': '正在加载此业务的角色...',
  'Start Date': '开始日期',
  'End Date (Optional)': '结束日期（可选）',
  'Not set': '未设置',
  'Save Changes': '保存更改',
  'Save User': '保存用户',
  'Full Name required': '必须填写全名',
  'Born Date required': '必须填写出生日期',
  'Phone Number required': '必须填写电话号码',
  'Enter a valid phone number': '请输入有效的电话号码',
  'Loading roles': '正在加载角色',
  'Active Role required': '必须选择启用的角色',
  'Select status': '选择状态',
  'Select role': '选择角色',
  'Last Working Date': '最后工作日',
  'Inactive': '停用',
  'Action taken': '已采取的行动',
  'Add Complaint': '添加投诉',
  'Add Waste Record': '添加损耗记录',
  'Age': '年龄',
  'All reports reviewed': '所有报告均已审核',
  'Any unsaved values on this screen will be replaced.':
      '此页面中未保存的数值将被替换。',
  'Bill Number': '账单编号',
  'Bulk submission is risky. Check every record. This action cannot be undone.':
      '批量提交有风险。请检查每条记录。此操作无法撤销。',
  'Camera': '相机',
  'Carousel position': '轮播位置',
  'Cash Received By': '现金接收人',
  'Complaint Information': '投诉信息',
  'Complaint report created': '投诉报告已创建',
  'Complaint updated': '投诉已更新',
  'Complete all pending items': '完成所有待处理项目',
  'Copy': '复制',
  'Copy SKUs from Business': '从业务复制SKU',
  'Copy from another business': '从其他业务复制',
  'Copy selected SKUs with their tags and suppliers.':
      '复制所选SKU及其标签和供应商。',
  'Customer Gender': '客户性别',
  'Daily Sales Input': '每日销售输入',
  'Daily photos submitted': '每日照片已提交',
  'Delete Advertisement?': '删除广告？',
  'End date & time *': '结束日期和时间 *',
  'End date and time must be later than start date and time.':
      '结束日期和时间必须晚于开始日期和时间。',
  'Enter the full platform amount. EastApp includes 60% in Total Sales and estimates 40% as platform commission.':
      '请输入完整的平台金额。EastApp将60%计入总销售额，并把40%估算为平台佣金。',
  'Estimated Age': '估计年龄',
  'Explain why the bill was voided': '说明账单作废原因',
  'Female': '女',
  'Gallery': '相册',
  'Gender': '性别',
  'Google Maps': 'Google地图',
  'Google rating unavailable': '无法获取Google评分',
  'Image, start date/time and end date/time are compulsory.':
      '图片、开始日期/时间和结束日期/时间均为必填项。',
  'Inventory Health': '库存健康度',
  'Item': '项目',
  'Item name': '项目名称',
  'Male': '男',
  'No advertisements yet.': '暂无广告。',
  'No caption needed. Take at least five operational photos each day.':
      '无需说明文字。每天至少拍摄五张运营照片。',
  'No checklist set.': '未设置检查清单。',
  'No complaints recorded': '暂无投诉记录',
  'No inventory risks detected': '未发现库存风险',
  'No photos taken today': '今天尚未拍照',
  'No submitted Sales reports in this date range':
      '此日期范围内没有已提交的销售报告',
  'No void bills recorded.': '没有作废账单记录。',
  'No waste records yet': '暂无损耗记录',
  'Non-SKU item': '非SKU项目',
  'Only active advertisements publish during their schedule.':
      '只有启用的广告会在排期内发布。',
  'Open': '未解决',
  'Optional': '可选',
  'Optional stock item': '库存项目（可选）',
  'Other': '其他',
  'Position': '位置',
  'Priority Risks': '优先风险',
  'Proceed': '继续',
  'Quantity': '数量',
  'Reason': '原因',
  'Recent Waste Evidence': '近期损耗凭证',
  'Record': '记录',
  'Record Void Bill': '记录作废账单',
  'Record this void bill?': '记录此作废账单？',
  'Refresh loaded range': '刷新已加载范围',
  'Replace Photo': '更换照片',
  'Replace SKU Photo': '更换SKU照片',
  'Report Date': '报告日期',
  'Report evidence could not be loaded.': '无法加载报告凭证。',
  'Resolved': '已解决',
  'Retry Camera': '重试相机',
  'Sales Report Loader': '销售报告加载器',
  'Sales Submission Details': '销售提交详情',
  'Sales report submitted': '销售报告已提交',
  'Search source SKU': '搜索来源SKU',
  'Select Sales report dates': '选择销售报告日期',
  'Select a date range, then tap Load Report.':
      '选择日期范围，然后点击加载报告。',
  'Select a maximum of 30 days.': '最多选择30天。',
  'Select up to 30 days, then load submitted reports.':
      '最多选择30天，然后加载已提交的报告。',
  'Source business': '来源业务',
  'Start date & time *': '开始日期和时间 *',
  'Submission Details': '提交详情',
  'Submit Complaint': '提交投诉',
  'Submit Waste Report': '提交损耗报告',
  'Submit customer complaint?': '提交客户投诉？',
  'Submit daily photo batch?': '提交每日照片批次？',
  'Submit sales report for approval?': '提交销售报告审批？',
  'Submit waste report?': '提交损耗报告？',
  'Switch sales report date?': '切换销售报告日期？',
  'Tap to edit': '点击编辑',
  'This advertisement will be removed permanently.': '此广告将被永久删除。',
  'Total Sales is calculated by the server: Cash Total + eWallet Total + 60% of Gross Food Delivery Sales.':
      '总销售额由服务器计算：现金总额 + eWallet总额 + 外卖平台总销售额的60%。',
  'Unknown': '未知',
  'Until': '截至',
  'Update': '更新',
  'Update Complaint': '更新投诉',
  'Update complaint status?': '更新投诉状态？',
  'Use Range': '使用此范围',
  'Use a wide banner image. Recommended ratio: 3.45:1.':
      '请使用宽幅横幅图片。建议比例：3.45:1。',
  'Void Bills': '作废账单',
  'Void Bills (Optional)': '作废账单（可选）',
  'Void bill created': '作废账单已创建',
  'Void bill recorded': '作废账单已记录',
  'Waste report submitted': '损耗报告已提交',
  'What action was taken?': '采取了什么行动？',
  'What did the customer complain about?': '客户投诉了什么？',
  'Why was this item wasted?': '为什么损耗此项目？',
  'e.g. V-001283': '例如 V-001283',
  'kg / pcs': '公斤 / 件',
  'Take a clear photo of the void bill.': '请清晰拍摄作废账单。',
  'Bill number is compulsory.': '账单编号为必填项。',
  'This bill number is already recorded.': '此账单编号已记录。',
  'Void reason is compulsory.': '作废原因为必填项。',
  'Enter a valid void amount.': '请输入有效的作废金额。',
  'Expand only when a bill was voided.': '仅在有账单作废时展开。',
  'Cash Total, Gross Food Delivery Sales and eWallet Total are required. Enter 0 when a payment channel has no sales.':
      '现金总额、外卖平台总销售额和eWallet总额均为必填项。某付款渠道没有销售额时请输入0。',
  'Payment totals must be valid non-negative amounts.':
      '付款总额必须是有效的非负金额。',
  'Cash Received By is required.': '现金接收人为必填项。',
  'Staff on Duty is required and must be at least 1.':
      '值班员工为必填项，且至少为1人。',
  'Finish recording this void bill, or clear the optional fields before submitting Sales.':
      '提交销售报告前，请完成此作废账单记录或清除可选字段。',
  'Take a clear waste photo.': '请清晰拍摄损耗项目。',
  'Select a SKU or enter the item name.': '请选择SKU或输入项目名称。',
  'Enter a valid waste quantity.': '请输入有效的损耗数量。',
  'Unit is compulsory.': '单位为必填项。',
  'Enter a valid estimated unit cost.': '请输入有效的预计单位成本。',
  'Waste reason is compulsory.': '损耗原因为必填项。',
  'Take a complaint photo.': '请清晰拍摄投诉凭证。',
  'Enter an estimated age from 1 to 120.': '请输入1至120岁的估计年龄。',
  'Complaint information is compulsory.': '投诉信息为必填项。',
  'Action taken is compulsory.': '已采取的行动为必填项。',
  'Compensation cannot be negative.': '赔偿金额不能为负数。',
  'Enter an action and valid compensation amount.':
      '请输入已采取的行动和有效的赔偿金额。',
  'Minimum achieved': '已达到最低要求',
  'Approve Report': '批准报告',
  'Reject Report': '拒绝报告',
  'Optional approval note': '审批备注（可选）',
  'Rejection reason is compulsory': '拒绝原因为必填项',
  'Approve this report?': '批准此报告？',
  'Reject this report?': '拒绝此报告？',
  'Report approved': '报告已批准',
  'Report rejected': '报告已拒绝',
  'Tap to retake': '点击重新拍摄',
  'Void Bill Photo': '作废账单照片',
  'Waste Photo': '损耗照片',
  'Complaint Photo': '投诉照片',
  'Photo evidence is compulsory for every waste record.':
      '每条损耗记录都必须提供照片凭证。',
  'Capture the full bill including number and amount.':
      '请拍摄完整账单，包括编号和金额。',
  'Capture relevant evidence while respecting customer privacy.':
      '请在尊重客户隐私的前提下拍摄相关凭证。',
  'Gross Food Delivery Sales': '外卖平台总销售额',
  'Estimated Unit Cost': '预计单位成本',
  'Compensation Amount (Optional)': '赔偿金额（可选）',
  'Compensation Amount': '赔偿金额',
  'Critical': '严重',
  'High': '高',
  'Overstock': '库存过多',
  'Daily Photo': '每日照片',
  'Create Advertisement': '创建广告',
  'Edit Advertisement': '编辑广告',
  'Upload advertisement image': '上传广告图片',
  'Replace image': '更换图片',
  'Save Advertisement': '保存广告',
  'Published': '已发布',
  'Scheduled': '已排期',
  'No other business is available.': '没有其他可用业务。',
  'Clear visible': '清除可见项',
  'Select visible': '选择可见项',
  'Copying…': '正在复制…',
  'The photo, customer estimate, complaint and action will be stored for business review.':
      '照片、客户估计、投诉内容和处理行动将保存供业务审核。',
  'Take a clear photo of the SKU.': '请清晰拍摄SKU。',
  'Void Amount': '作废金额',
  '30-day Loss': '30天损耗',
  'Records': '记录',
  'Waste Evidence': '损耗凭证',
  'Technical Error': '技术错误',
  'Error details copied': '错误详情已复制',
  'Please review the information carefully. This will change business data.':
      '请仔细检查信息。此操作将更改业务数据。',
  'Help': '帮助',
  'Logout': '退出登录',
  'No ratings yet': '暂无评分',
  'Delete Selected SOP?': '删除所选SOP？',
  'Submitted count': '已提交盘点',
  'Reviewed count': '已审核盘点',
  'Created task': '已创建任务',
  'Debug report copied': '调试报告已复制',
  'Copy Debug Report': '复制调试报告',
  'Ask the tester to paste this report into WhatsApp when something fails inside the app.':
      '应用内发生问题时，请让测试人员把此报告粘贴到WhatsApp。',
  'Report preview': '报告预览',
  'Select an active user.': '请选择一位启用的用户。',
  'Choose at least +1 or -1 point.': '请至少选择+1或-1分。',
  'Reason is compulsory.': '原因为必填项。',
  'Confirm point adjustment': '确认积分调整',
  'Points updated': '积分已更新',
  'Point Adjustment': '积分调整',
  'Active User': '启用用户',
  'Decrease 1 point': '减少1分',
  'Add 1 point': '增加1分',
  'Reason *': '原因 *',
  'Compulsory reason for this adjustment': '此调整的必填原因',
  'Apply Adjustment': '应用调整',
  'Current Business Ranking': '当前业务排名',
  'No active users found.': '未找到启用用户。',
  'Enter the 10-character Setup Code shown by EastApp.':
      '请输入EastApp显示的10位设置代码。',
  'Initial Setup Code': '初始设置代码',
  'Copy this one-time code. It is available only before Initial Setup is completed.':
      '复制此一次性代码。它仅在完成初始设置前可用。',
  'Valid until': '有效期至',
  'Copy Code': '复制代码',
  'Show Setup Code': '显示设置代码',
  'Setup Code copied.': '设置代码已复制。',
  'Company Code must contain 2–32 letters, numbers, _ or -.':
      '公司代码必须包含2至32个字母、数字、_或-。',
  'Employee ID Prefix must contain 1–3 letters.':
      '员工编号前缀必须包含1至3个字母。',
  'Select the Google business location.': '请选择Google业务位置。',
  'Password must contain at least 4 characters.': '密码必须至少包含4个字符。',
  'Passwords do not match.': '两次输入的密码不一致。',
  'Complete Initial Setup?': '完成初始设置？',
  'This will create the first business and Owner account. The selected Google location will be used as the office reference for attendance distance.':
      '这将创建第一个业务和Owner账户。所选Google位置将作为考勤距离的办公地点基准。',
  'Owner Account Created': 'Owner账户已创建',
  'Use the Company Code, Employee ID and password to sign in.':
      '请使用公司代码、员工编号和密码登录。',
  'Continue to Login': '继续登录',
  'Initial Setup': '初始设置',
  'Create the first business and Owner account. Employee ID is generated automatically.':
      '创建第一个业务和Owner账户。员工编号将自动生成。',
  'Setup Code': '设置代码',
  '10-character code': '10位代码',
  'Business Name': '业务名称',
  'Example: The East': '例如：The East',
  'Company Code': '公司代码',
  'Example: EAST': '例如：EAST',
  'Employee ID Prefix': '员工编号前缀',
  'Example: E': '例如：E',
  'Full name': '全名',
  'Create a password': '创建密码',
  'Confirm Password': '确认密码',
  'Enter the password again': '再次输入密码',
  'Create Business & Owner': '创建业务和Owner',
  'Backend unavailable': '后端不可用',
  'Return to login': '返回登录',
  'Google Business Location': 'Google业务位置',
  'Search and select the exact Google Maps listing':
      '搜索并选择准确的Google Maps地点',
  'Select Business Location': '选择业务位置',
  'Search business name or address': '搜索业务名称或地址',
  'Searching Google Maps…': '正在搜索Google Maps…',
  'Type at least 2 characters.': '请至少输入2个字符。',
  'No matching location found.': '未找到匹配的位置。',
  'Google Business Location is required. Replace HARDCODED_API_KEY in GooglePlacesProperties.java, restart the backend, then search again.':
      '必须设置Google业务位置。请替换GooglePlacesProperties.java中的HARDCODED_API_KEY，重启后端后再次搜索。',
  'Country Code': '国家/地区代码',
  'Search country or code': '搜索国家/地区或代码',
  'Phone number': '电话号码',
  'Malaysia': '马来西亚',
  'Singapore': '新加坡',
  'Indonesia': '印度尼西亚',
  'Thailand': '泰国',
  'Philippines': '菲律宾',
  'Vietnam': '越南',
  'Brunei': '文莱',
  'China': '中国',
  'Hong Kong': '中国香港',
  'Taiwan': '中国台湾',
  'Japan': '日本',
  'South Korea': '韩国',
  'India': '印度',
  'Australia': '澳大利亚',
  'United Kingdom': '英国',
  'United States / Canada': '美国 / 加拿大',
  'Edit this business, create a business or switch context':
      '编辑此业务、创建业务或切换业务',
  'View and edit this business': '查看并编辑此业务',
  'Create': '创建',
  'Search other businesses': '搜索其他业务',
  'Other Businesses': '其他业务',
  'No other business context is assigned.': '未分配其他业务上下文。',
  'Prefix': '前缀',
  'Business Name required': '必须填写业务名称',
  'Company Code required': '必须填写公司代码',
  'Use 2–32 letters, numbers, _ or -': '请使用2至32个字母、数字、_或-',
  'Employee ID Prefix required': '必须填写员工编号前缀',
  'Use 1–3 letters': '请使用1至3个字母',
  'Google business location required': '必须选择Google业务位置',
  'Update Business?': '更新业务？',
  'Create Business?': '创建业务？',
  'This updates only this business.': '这只会更新此业务。',
  'This creates a new isolated business, default roles and a separate Owner employee ID for every existing Owner.':
      '这将创建一个独立的新业务、默认角色，并为每位现有Owner创建独立的Owner员工编号。',
  'Edit Business': '编辑业务',
  'Create Business': '创建业务',
  'Example: June Coffee': '例如：June Coffee',
  'Example: JUNE': '例如：JUNE',
  'Example: J': '例如：J',
  'Company Code and Employee ID Prefix cannot change after creation.':
      '创建后不能更改公司代码和员工编号前缀。',
  'Create Supplier?': '创建供应商？',
  'This will create a new supplier for the this business.':
      '这将为此业务创建新供应商。',
  'Submit Daily Stock Count?': '提交每日库存盘点？',
  'This will create stock-count records and update the selected SKU balances.':
      '这将创建库存盘点记录并更新所选SKU的库存。',
  'Submit Receiving?': '提交收货？',
  'This will create the receiving record and update the received SKU balances.':
      '这将创建收货记录并更新已收货SKU的库存。',
  'Update SKU?': '更新SKU？',
  'This will save the edited SKU details and stock settings.':
      '这将保存已编辑的SKU详情和库存设置。',
  'Update SKU Assignees?': '更新SKU负责人？',
  'This will replace the assignee list for the selected SKU.':
      '这将替换所选SKU的负责人列表。',
  'Delete Selected Suppliers?': '删除所选供应商？',
  'This will permanently delete the selected unassigned suppliers.':
      '这将永久删除所选且尚未分配的供应商。',
  'Update Supplier?': '更新供应商？',
  'This will save the edited supplier information.':
      '这将保存已编辑的供应商信息。',
  'Delete Supplier?': '删除供应商？',
  'This will permanently delete this unassigned supplier.':
      '这将永久删除此尚未分配的供应商。',
  'Create Tag?': '创建标签？',
  'This will create a new Stock tag for the this business.':
      '这将为此业务创建新的库存标签。',
  'Delete Selected Tags?': '删除所选标签？',
  'This will permanently delete the selected unassigned tags.':
      '这将永久删除所选且尚未分配的标签。',
  'Update Tag?': '更新标签？',
  'This will rename the selected tag.': '这将重命名所选标签。',
  'Delete Tag?': '删除标签？',
  'This will permanently delete this unassigned tag.':
      '这将永久删除此尚未分配的标签。',
  'Create SKU?': '创建SKU？',
  'This will upload the thumbnail and create a new SKU for the this business.':
      '这将上传缩略图并为此业务创建新SKU。',
  'Submit Task?': '提交任务？',
  'This will submit the task and photo evidence for manager review.':
      '这将提交任务和照片凭证供经理审核。',
  'Reject Task?': '拒绝任务？',
  'This will reject the submitted task and save the review result.':
      '这将拒绝已提交的任务并保存审核结果。',
  'Approve Task?': '批准任务？',
  'This will approve the submitted task and award the selected score.':
      '这将批准已提交的任务并授予所选分数。',
  'Confirm without provider call': '不调用服务商并确认',
  'Load Report': '加载报告',
  'Reload Report': '重新加载报告',
  'Resolve Complaint': '解决投诉',
  'Update Resolution': '更新处理结果',
  'Price Range': '价格范围',
  'Previous Balance': '之前库存',
  'Below Min': '低于最低值',
  'Checked Values': '已检查数值',
  'Remarks': '备注',
  'Task Title': '任务标题',
  'Checks': '检查项',
  'Stock Task': '库存任务',
  'Goods Photo': '货物照片',
  'Processing. Please wait.': '正在处理，请稍候。',
  'All Roles': '所有角色',
  'Unknown Tag': '未知标签',
  'Temporary disabled': '暂时停用',
  'Complete supplier, SKU & qty': '请完整填写供应商、SKU和数量',
  'Add invoice & goods photos': '请添加发票和货物照片',
  'Enter valid stock numbers': '请输入有效的库存数值',
  'Enter valid stock number': '请输入有效的库存数值',
  'Complete every SKU': '请完整填写每个SKU',
  'Updated': '已更新',
  'Created': '已创建',
  'approved': '已批准',
  'completed': '已完成',
  'in_progress': '进行中',
  'items': '项',
  'pending': '待处理',
  'points': '积分',
  'points earned': '已获得积分',
  'rejected': '已拒绝',
  'submitted': '已提交',
  'user': '用户',
  'Knowledge Audit': '知识审计',
  'Measure recorded SOP playback time': '衡量已记录的SOP播放时长',
  'Playback effort': '播放投入',
  'By Employee': '按员工',
  'Video Analytics': '视频分析',
  'Employee learning effort': '员工学习投入',
  'Search, then tap an employee to load': '搜索后点击员工即可加载',
  'Name, employee ID, role or phone': '姓名、员工编号、职位或电话',
  'Search Employee': '搜索员工',
  'Unable to load employees. Try again.': '无法加载员工，请重试。',
  'Unable to load employee learning time.': '无法加载员工学习时长。',
  'Unable to load video analytics. Try again.': '无法加载视频分析，请重试。',
  'No employee found.': '未找到员工。',
  'Total active playback time': '实际播放总时长',
  'SOP videos watched': '已观看的SOP视频',
  'No recorded active playback time yet.': '暂无已记录的实际播放时长。',
  'Last watched': '最后观看',
  'Compare SOP videos by total active playback time': '按实际播放总时长比较SOP视频',
  'Load Video Analytics': '加载视频分析',
  'Refresh Video Analytics': '刷新视频分析',
  'Data loads only when u press this button.': '仅在按下此按钮时加载数据。',
  'All active playback': '全部实际播放时长',
  'Unique employees': '独立员工数',
  'Most watched SOP videos': '观看最多的SOP视频',
  'employees': '名员工',
  'No SOP videos available.': '暂无SOP视频。',
  'Playback time is recorded only while the SOP video is actively playing in the foreground. It cannot prove attention or understanding.':
      '仅记录SOP视频在前台实际播放的时间，不能证明员工是否专注或理解内容。',
};
