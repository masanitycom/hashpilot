-- ステップ3: System Emails
SET session_replication_role = replica;

-- Data for Name: system_emails; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."system_emails" ("id", "subject", "body", "from_name", "from_email", "email_type", "sent_by", "target_group", "created_at") VALUES
	('ae9d7c9d-58c5-4d7f-b0a2-d02e92092b19', '相談', 'テスト', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'basarasystems@gmail.com', NULL, '2025-10-11 15:26:50.726202+00'),
	('221311d8-1bca-407d-89f3-0c6c21542777', 'テスト配信', 'tesuto配信です', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'basarasystems@gmail.com', NULL, '2025-10-11 15:47:31.417387+00'),
	('5dc8bf01-b576-40ad-a4aa-6a5335e5b00c', 'テスト', 'テストです', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'basarasystems@gmail.com', NULL, '2025-10-11 15:50:36.200666+00'),
	('3b097ca9-5701-490b-a374-d1e390c7cb1d', 'テスト、メール', 'テストザンス', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'basarasystems@gmail.com', NULL, '2025-10-11 15:53:30.991077+00'),
	('05ac8a2d-ecc6-4c2d-8bc0-5cd2b160a768', 'テスト', 'テストしちゃう', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'basarasystems@gmail.com', NULL, '2025-10-12 00:46:11.411703+00'),
	('7b8898c2-ab7f-4d06-93e5-fff23119d947', 'NFT受取アドレス設定のお願い', '{{email}}　
{{user_id}}様

お世話になります。
ハッシュパイロットsupportです', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'basarasystems@gmail.com', NULL, '2025-10-12 01:10:43.710451+00'),
	('7824ab13-8743-4559-a4a8-f8c6edb8afa8', 'テスト', '{{user_id}}様

テスト', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', NULL, '2025-10-12 05:13:17.678064+00'),
	('0f4fcea9-649c-4754-80ce-960a100351bb', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。

{{user_id}}
{{email}}
様

お世話になっております。
HASH PILOTサポートチームからのご案内です。

既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。

・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。
※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。
※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。

・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。
※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。
※(例)12345678のような仮設定状態の方は必ず修正して下さい。

HASH PILOTダッシュボードURL
https://hashpilot.net/

何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。
https://lin.ee/7gT3x5h

HASH PILOTサポートチーム', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', NULL, '2025-10-14 05:52:49.14541+00'),
	('d8cdbf6b-4569-47c7-9a4e-1eda860f81fa', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。

{{user_id}}
{{email}}
様

お世話になっております。
HASH PILOTサポートチームからのご案内です。

既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。

・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。
※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。
※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。

・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。
※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。
※(例)12345678のような仮設定状態の方は必ず修正して下さい。

HASH PILOTダッシュボードURL
https://hashpilot.net/

何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。
https://lin.ee/7gT3x5h

HASH PILOTサポートチーム', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', NULL, '2025-10-14 07:23:19.487697+00'),
	('c5cb526e-dfac-4f82-9ca8-7785ae0b8856', 'テスト', '※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。

{{user_id}}
{{email}}
様

お世話になっております。
HASH PILOTサポートチームからのご案内です。

既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。

・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。
※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。
※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。

・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。
※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。
※(例)12345678のような仮設定状態の方は必ず修正して下さい。

HASH PILOTダッシュボードURL
https://hashpilot.net/

何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。
https://lin.ee/7gT3x5h

HASH PILOTサポートチーム', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', NULL, '2025-10-14 07:24:52.212002+00'),
	('1f2af4a7-10a0-4cfc-a47b-92d150189c59', 'テスト', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        {{user_id}}様<br><br>テストです<br><br><a href="https://<a href="http://www.yahoo.co.jp/"" style="color: #3b82f6; text-decoration: underline;">www.yahoo.co.jp/"</a> style="color: #3b82f6; text-decoration: underline;">https://<a href="http://www.yahoo.co.jp/</a>" style="color: #3b82f6; text-decoration: underline;">www.yahoo.co.jp/</a></a>
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'basarasystems@gmail.com', 'all', '2025-10-14 07:38:30.524493+00'),
	('7d62a04c-1cd1-40be-8020-2b0389a48f4e', 'てすちん', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        {{email}}<br>{{user_id}}様<br><br>お世話になります。<br><br><a href="https://www.yahoo.co.jp/" style="color: #3b82f6; text-decoration: underline;">https://www.yahoo.co.jp/</a>
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'basarasystems@gmail.com', 'all', '2025-10-14 07:51:55.034872+00'),
	('61f63519-3e0e-4fb2-b89e-911f5d1b55f2', 'テスト', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 08:10:04.14271+00'),
	('7a1c6ec2-b3f1-4991-9c88-cf3f7b80e27d', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'broadcast', 'support@dshsupport.biz', 'all', '2025-10-14 08:13:10.700335+00'),
	('09305467-66c5-40d6-84d9-60afb5db4240', 'テスト送信', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        お世話になります。<br>メールシステム確認のためのテスト送信です。
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'broadcast', 'basarasystems@gmail.com', 'all', '2025-10-14 08:17:22.684346+00'),
	('ee705a0f-90ca-4b00-943c-a7ba8d252555', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 09:53:28.537902+00'),
	('792fe399-0474-4511-83b1-ac89eccbcfec', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:20:14.499221+00'),
	('6b390f36-5cbc-4780-897e-2798b431a272', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:29:30.042465+00'),
	('f9e6dae8-680c-4d9e-baa3-9d3da66ccc51', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:34:56.120252+00'),
	('6b36b7f6-4231-402d-811b-abfb30e81f15', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:35:36.351005+00'),
	('80abfb3d-72a1-4b7e-9f49-18d77b618bd5', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:36:04.334787+00'),
	('ef94314d-4025-4489-9c38-33badf3600a3', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:36:24.749742+00'),
	('ab7e1c36-f149-4b13-8740-02b0ac9a1259', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:36:50.291822+00'),
	('3f40764e-6afd-4dba-8f96-0a63a5ce57b1', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:37:12.955367+00'),
	('b7950f9e-83c5-4e9f-967c-8b3138822784', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:37:35.875624+00'),
	('9294ee06-6256-43c0-a82c-36685a27ae81', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:38:39.350362+00'),
	('8026aa0c-58be-4ff4-b2da-0322b19fd24f', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:39:00.580515+00'),
	('1d7a5b00-c1ec-4eaf-9350-2526d4e53493', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:37:58.920441+00'),
	('571e7914-62f6-4fc4-bd6f-f8e90187c992', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:38:20.338201+00'),
	('ecd38331-ae2d-42b6-92ad-04040c0edfff', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:39:24.092875+00'),
	('8dd22319-87de-4f82-8bfa-3f496a293993', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:39:45.436156+00'),
	('61e3a687-fc8c-4c64-bbee-afc4ec9bbcf5', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:40:06.956779+00'),
	('42b72fad-6ad7-4910-bc39-773537532b05', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:40:28.564396+00'),
	('b4f2d016-f99f-4f8c-b300-999a22f3cde7', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:40:49.352825+00'),
	('b5a1f0e7-9ea5-4ea3-9e5e-33b5083cfaaa', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:41:14.896464+00'),
	('4ad7b7a6-40f1-400f-9aae-7e0cf7e99255', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:41:34.802657+00'),
	('65372585-a383-4a3a-971f-184e1763f2a3', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:42:16.419374+00'),
	('ba617dcf-e939-43f5-923a-ef13a728ed3b', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:41:56.998349+00'),
	('a3306d06-3c05-4dcb-a55e-9e2ef42db061', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:42:53.638238+00'),
	('d68d97f4-2511-407f-9215-b5ec08a27e9b', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:43:12.795216+00'),
	('72b24429-255d-4434-9349-6d6e651a8bf2', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:43:34.927613+00'),
	('b01cbefc-525d-4265-bde1-8d4a9e91ff7a', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:43:54.768079+00'),
	('20b6c186-00c7-47d7-b5fe-dc42ce4e6976', '【HASH PILOT】NFT受け取りアドレスとCoinwのUIDについて', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ※このメールは送信専用メールアドレスから配信されていますので、ご返信をいただいてもお答えできませんのでご了承ください。<br><br>{{user_id}}<br>{{email}}<br>様<br><br>お世話になっております。<br>HASH PILOTサポートチームからのご案内です。<br><br>既にダッシュボートにNFT受け取りアドレスが設定されている方は、設定された受け取りアドレスにNFTが配布されております。<br><br>・現在正常に設定されていない方につきましては、ダッシュボードよりNFT受け取りアドレスの設定をお願いいたします。<br>※NFT受け取りアドレスはセーフパル、メタマスク等の取引所以外のウォレット(BEP20)をご記入下さい。<br>※(例)0x12345、メールアドレスを記入されている方、0xから始まらない明らかに受け取りアドレスと断定できない(BSCスキャンにて読み取れない)英数字、メールアドレスを記入されている方は必ず修正して下さい。<br><br>・CoinwのUIDについてですが、必ず正しいご自身のUIDを設定お願いいたします。<br>※正しく設定されていない場合は、運用実績分のUSDTがエアドロップされませんのでご了承下さい。<br>※(例)12345678のような仮設定状態の方は必ず修正して下さい。<br><br>HASH PILOTダッシュボードURL<br><a href="https://hashpilot.net/" style="color: #3b82f6; text-decoration: underline;">https://hashpilot.net/</a><br><br>何かご不明点などございましたら以下サポートラインまでお問い合わせ下さい。<br><a href="https://lin.ee/7gT3x5h" style="color: #3b82f6; text-decoration: underline;">https://lin.ee/7gT3x5h</a><br><br>HASH PILOTサポートチーム
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-14 10:44:22.042491+00'),
	('8e094b52-0092-4f96-aaa1-5d4063e68517', '【HASH PILOT】VVIP bot 正式稼働開始に関するご案内', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        【重要】<br><br>VVIP bot 正式稼働開始に関するご案内<br><br>平素よりご愛顧いただき、誠にありがとうございます。<br><br>まず、最近の暗号資産市場についてご報告申し上げます。<br><br>10月10日、米国による中国製ハイテク製品への追加関税（最大100％）発表をきっかけに、暗号資産市場全体が急落いたしました。<br><br>ビットコインは高値から一時14％超、イーサリアムも約12％下落し、約190億ドル規模のレバレッジ清算が発生するなど、市場が一時的に大きく混乱しました。<br><br>しかしながら、VVIP botはこの暴落局面においても安定したパフォーマンスを維持し、相場の急変動をほとんど受けることなく堅調な結果を出しております。<br><br>テスト期間中のデータからも、リスク制御機能が十分に機能していることを確認しております。<br><br>VVIP botは10月3日よりテスト運用を開始し、現在も好成績を継続中です。<br><br>当サービスでは入金サイクルを以下の通り設けております。<br><br>•5日締め → 15日より運用開始<br>•20日締め → 翌月1日より運用開始<br><br>今回の初回運用については、直近の市場急落を踏まえ、相場が安定したことを確認した上で正式稼働することを最優先といたしました。<br><br>そのため、VVIP botの正式稼働は11月1日より開始いたします。<br><br>この判断は、短期的な成果を急ぐよりも、安定した市場環境下で正確かつ信頼性の高いデータを取得し、皆様の大切な資金を安全に運用するためのものです。<br><br>初回稼働にあたりご不便をおかけいたしますが、VVIP botは相場の急変にも動じない堅牢な設計で、長期的な安定運用を目指してまいります。<br><br>焦らず確実に、透明性の高い資金運用を行ってまいりますので、どうぞご安心ください。<br><br>今後とも変わらぬご理解とご支援を賜りますようお願い申し上げます。<br><br>――――――――――<br>Hash Pilot事務局<br>――――――――――
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-16 11:18:22.773892+00'),
	('0109f2d6-157d-4373-a429-30125c01d5ec', '【HASH PILOT】VVIP bot 正式稼働開始に関するご案内', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        【重要】<br><br>平素よりご愛顧いただき、誠にありがとうございます。<br><br>まず、最近の暗号資産市場についてご報告申し上げます。<br><br>10月10日、米国による中国製ハイテク製品への追加関税（最大100％）発表をきっかけに、暗号資産市場全体が急落いたしました。<br><br>ビットコインは高値から一時14％超、イーサリアムも約12％下落し、約190億ドル規模のレバレッジ清算が発生するなど、市場が一時的に大きく混乱しました。<br><br>しかしながら、VVIP botはこの暴落局面においても安定したパフォーマンスを維持し、相場の急変動をほとんど受けることなく堅調な結果を出しております。<br><br>テスト期間中のデータからも、リスク制御機能が十分に機能していることを確認しております。<br><br>VVIP botは10月3日よりテスト運用を開始し、現在も好成績を継続中です。<br><br>当サービスでは入金サイクルを以下の通り設けております。<br><br>•5日締め → 15日より運用開始<br>•20日締め → 翌月1日より運用開始<br><br>今回の初回運用については、直近の市場急落を踏まえ、相場が安定したことを確認した上で正式稼働することを最優先といたしました。<br><br>そのため、VVIP botの正式稼働は11月1日より開始いたします。<br><br>この判断は、短期的な成果を急ぐよりも、安定した市場環境下で正確かつ信頼性の高いデータを取得し、皆様の大切な資金を安全に運用するためのものです。<br><br>初回稼働にあたりご不便をおかけいたしますが、VVIP botは相場の急変にも動じない堅牢な設計で、長期的な安定運用を目指してまいります。<br><br>焦らず確実に、透明性の高い資金運用を行ってまいりますので、どうぞご安心ください。<br><br>今後とも変わらぬご理解とご支援を賜りますようお願い申し上げます。<br><br>――――――――――<br>Hash Pilot事務局<br>――――――――――
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'individual', 'support@dshsupport.biz', 'all', '2025-10-16 11:48:29.294502+00'),
	('f52ea44c-96b2-4145-b442-2941a7f8312c', 'Hash Pilotスタート記念！本日19:00〜Zoom説明会＆報告会開催のお知らせ', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        Hash Pilot運営事務局でございます。<br>平素より弊社サービスをご利用いただき、誠にありがとうございます。<br><br>11月1日より、いよいよ Hash Pilotの正式運用がスタート いたしました！<br>そして本日、昨日分の収益がバックオフィスに反映されております。<br><br>この節目を記念し、本日19:00よりZoom説明会＆報告会 を開催いたします。<br><br>開催内容<br>・市場や相場の最新動向について<br>・バックオフィスの操作・確認方法<br>・今後の展望やお知らせ<br><br>Hash Pilotをより深く理解し、今後の運用をさらに有意義に進めていただくための大切な内容をお伝えいたします。<br><br>本日のzoomでは、Hash Pilotに強い情熱を持つ若手メンバー2名 がスピーカーとして登壇いたします。<br>熱意と向上心に溢れる2人が、皆様にわかりやすく、楽しくご説明いたします！<br><br>今後はサポートメンバーとしても活躍してまいりますので、ぜひこの機会にお顔を見にいらしてください😊<br><br>ZOOMはこちらから↓↓↓<br>2025年11月2日（日）19:00～<br><a href="https://us06web.zoom.us/j/5558105848?pwd=dFlsWVZyd0x0RE9uSXJkeFAwOGFnZz09" style="color: #3b82f6; text-decoration: underline;">https://us06web.zoom.us/j/5558105848?pwd=dFlsWVZyd0x0RE9uSXJkeFAwOGFnZz09</a><br>ミーティング ID: 555 810 5848<br>パスコード: 000000<br><br>皆様のご参加を心よりお待ちしております。<br>今後ともHash Pilotをどうぞよろしくお願いいたします。<br><br><br>Hash Pilot運営事務局<br><br><br>
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>', 'HASHPILOT', 'noreply@hashpilot.biz', 'broadcast', 'basarasystems@gmail.com', 'all', '2025-11-02 07:24:09.762374+00');


--
-- Data for Name: email_recipients; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."email_recipients" ("id", "email_id", "user_id", "to_email", "status", "sent_at", "read_at", "error_message", "resend_email_id", "created_at") VALUES
	('3d867f74-7c8e-4a44-9f57-b36dd34b7b3b', '7a1c6ec2-b3f1-4991-9c88-cf3f7b80e27d', '938133', 'kiyoko.winter@gmail.com', 'failed', NULL, NULL, '{"statusCode":429,"message":"You have reached your daily email sending quota.","name":"daily_quota_exceeded"}', NULL, '2025-10-14 08:13:10.700335+00'),
	('9188e944-512b-4604-a256-3fc229295e95', '8e094b52-0092-4f96-aaa1-5d4063e68517', '7041CD', 'fnishimura32@gmail.com', 'sent', '2025-10-16 11:21:09.384+00', NULL, NULL, 'e84f08f7-f7f6-423e-8f73-5bed6688bdc7', '2025-10-16 11:18:22.773892+00'),
	('b8da1eea-2371-4532-92b6-4db991a47420', '7a1c6ec2-b3f1-4991-9c88-cf3f7b80e27d', 'E83446', 'shinkansenboy752@gmail.com', 'read', '2025-10-14 08:13:24.711+00', '2025-10-15 06:18:03.042216+00', NULL, 'af712cf1-4937-4658-88ca-c79072b0cb51', '2025-10-14 08:13:10.700335+00'),

SET session_replication_role = DEFAULT;
