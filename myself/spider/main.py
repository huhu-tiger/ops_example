import sys
import requests
from bs4 import BeautifulSoup

def get_dygang_links(url):
    """
    抓取 dygang.net 网站的下载链接（迅雷或 magnet 链接）
    """
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'lxml')
        
        links = []
        # 查找所有包含下载链接的 a 标签
        for a in soup.find_all('a', href=True):
            href = a['href']
            if href.startswith('thunder://') or href.startswith('magnet:'):
                links.append(href)
        
        return links
    except Exception as e:
        print(f"Error fetching links: {e}")
        return []

def main():
    if len(sys.argv) != 2:
        print("用法: python main.py <网站地址>")
        print("例如: python main.py https://www.dygang.net/yx/20251206/58574.htm")
        sys.exit(1)
    
    url = sys.argv[1]
    
    if 'dygang.net' in url:
        print(f"正在抓取 {url} 的下载链接...")
        links = get_dygang_links(url)
        if links:
            print("找到的下载链接:")
            for link in links:
                print(link)
        else:
            print("未找到下载链接")
    else:
        print("不支持的网站。目前仅支持 dygang.net")

if __name__ == "__main__":
    main()
