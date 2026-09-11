class BadgeItem {
  const BadgeItem({required this.id,required this.name,required this.description,required this.ruleType,required this.ruleValue,required this.earned,this.iconUrl,this.awardedAt});
  final String id,name,description,ruleType; final int ruleValue; final bool earned; final String? iconUrl,awardedAt;
  factory BadgeItem.fromJson(Map<String,dynamic> j)=>BadgeItem(id:'${j['id']??''}',name:'${j['name_ar']??'شارة'}',description:'${j['description_ar']??''}',ruleType:'${j['rule_type']??''}',ruleValue:int.tryParse('${j['rule_value']??0}')??0,earned:j['earned']==true||'${j['earned']??0}'=='1',iconUrl:j['icon_url']?.toString(),awardedAt:j['awarded_at']?.toString());
}
class BadgeSnapshot {
  const BadgeSnapshot({required this.badges,required this.earnedCount,required this.totalCount,required this.newlyAwarded});
  final List<BadgeItem> badges; final int earnedCount,totalCount; final List<String> newlyAwarded;
  factory BadgeSnapshot.fromJson(Map<String,dynamic> j){final raw=j['badges']; return BadgeSnapshot(badges:raw is List?raw.whereType<Map>().map((e)=>BadgeItem.fromJson(Map<String,dynamic>.from(e))).toList():const [],earnedCount:int.tryParse('${j['earnedCount']??0}')??0,totalCount:int.tryParse('${j['totalCount']??0}')??0,newlyAwarded:j['newlyAwarded'] is List?j['newlyAwarded'].map((e)=>e.toString()).toList():const []);}
}
